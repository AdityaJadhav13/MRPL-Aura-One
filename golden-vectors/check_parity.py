#!/usr/bin/env python3
"""Verify that the Python research stack reproduces the golden vectors.

    python3 check_parity.py            # verify, exit non-zero on divergence
    python3 check_parity.py --verbose  # print every comparison

The Dart engine is checked against the same file by
`packages/measurement/test/golden/golden_vectors_test.dart`. Because both
stacks are compared against one authoritative set of expected values, agreement
with the file implies agreement with each other, and CI fails if either drifts.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

import doseband_reference as ref

HERE = os.path.dirname(os.path.abspath(__file__))


class Comparison:
    def __init__(self, verbose: bool):
        self.verbose = verbose
        self.checked = 0
        self.failures: list[str] = []

    def close(self, label: str, actual, expected, tolerance: float) -> None:
        self.checked += 1
        if isinstance(expected, (list, tuple)):
            if len(actual) != len(expected):
                self.failures.append(
                    f"{label}: length {len(actual)} != {len(expected)}"
                )
                return
            for i, (a, e) in enumerate(zip(actual, expected)):
                self.close(f"{label}[{i}]", a, e, tolerance)
            return

        if expected is None or actual is None:
            if expected is not actual:
                self.failures.append(f"{label}: {actual!r} != {expected!r}")
            return

        if isinstance(expected, bool) or isinstance(actual, bool):
            if bool(actual) != bool(expected):
                self.failures.append(f"{label}: {actual} != {expected}")
            return

        if isinstance(expected, int) and isinstance(actual, int):
            if actual != expected:
                self.failures.append(f"{label}: {actual} != {expected}")
            return

        if math.isnan(expected) or math.isnan(actual):
            if not (math.isnan(expected) and math.isnan(actual)):
                self.failures.append(f"{label}: {actual} != {expected}")
            return

        delta = abs(actual - expected)
        if delta > tolerance:
            self.failures.append(
                f"{label}: {actual!r} != {expected!r} (delta {delta:.3e} "
                f"> tolerance {tolerance:.1e})"
            )
        elif self.verbose:
            print(f"  ok  {label}: delta {delta:.3e}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    with open(os.path.join(HERE, "vectors.json"), encoding="utf-8") as handle:
        vectors = json.load(handle)

    if vectors.get("schema") != "doseband-golden-vectors/1":
        print(f"unexpected schema: {vectors.get('schema')}", file=sys.stderr)
        return 2

    tol = vectors["tolerances"]
    cases = vectors["cases"]
    fixture = vectors["fixture"]
    cmp = Comparison(args.verbose)

    # --- scalar transfer function ---------------------------------------
    for i, case in enumerate(cases["srgb_linearise"]):
        cmp.close(f"srgb_linearise[{i}]", ref.linearise(case["input"]),
                  case["expected"], tol["scalar_absolute"])
    for i, case in enumerate(cases["srgb_delinearise"]):
        cmp.close(f"srgb_delinearise[{i}]", ref.delinearise(case["input"]),
                  case["expected"], tol["scalar_absolute"])

    # --- colour space chain ---------------------------------------------
    for i, case in enumerate(cases["srgb_to_linear_to_xyz_to_lab"]):
        srgb = case["srgb"]
        linear = [ref.linearise(c) for c in srgb]
        xyz = ref.linear_to_xyz(*linear)
        lab = ref.xyz_to_lab(*xyz)
        cmp.close(f"linear[{i}]", linear, case["linear"], tol["colour_absolute"])
        cmp.close(f"xyz[{i}]", list(xyz), case["xyz"], tol["colour_absolute"])
        cmp.close(f"lab[{i}]", list(lab), case["lab"], tol["colour_absolute"])

    # --- colour difference ----------------------------------------------
    for i, case in enumerate(cases["delta_e"]):
        cmp.close(f"delta_e76[{i}]", ref.delta_e76(case["lab1"], case["lab2"]),
                  case["delta_e76"], tol["delta_e_absolute"])
        cmp.close(f"delta_e00[{i}]",
                  ref.delta_e2000(case["lab1"], case["lab2"]),
                  case["delta_e00"], tol["delta_e_absolute"])

    # --- QRsens normalisation -------------------------------------------
    qr = cases["qrsens_normalisation"]
    for form in ("equation_1", "equation_2"):
        for i, case in enumerate(qr[form]):
            actual = ref.qrsens_normalise(
                case["sensor"], qr["black"], qr["white"], form
            )
            cmp.close(f"qrsens.{form}[{i}].ok", actual is not None, case["ok"], 0)
            if case["ok"]:
                cmp.close(f"qrsens.{form}[{i}]", actual, case["expected"],
                          tol["colour_absolute"])

    # --- homography -------------------------------------------------------
    hom = cases["homography"]
    correspondences = [
        (tuple(c["badge_mm"]), tuple(c["image_px"])) for c in hom["correspondences"]
    ]
    matrix, _margin = ref.estimate_homography(correspondences)
    for r in range(3):
        cmp.close(f"homography[{r}]", matrix[r], hom["expected_matrix"][r],
                  tol["homography_absolute"])
    cmp.close("homography.reprojection_rms",
              ref.reprojection_rms(matrix, correspondences),
              hom["expected_reprojection_rms_px"], tol["homography_absolute"])

    # --- ROI statistics from the shared fixture image --------------------
    image = ref.PpmImage.load(os.path.join(HERE, fixture["image"]))
    if image.width != fixture["width"] or image.height != fixture["height"]:
        print("fixture image has unexpected dimensions", file=sys.stderr)
        return 2

    rois = {r["id"]: r for r in fixture["geometry"]["rois"]}
    samples = {}
    for roi_id, expected in cases["roi_statistics"].items():
        actual = ref.sample_roi(
            image,
            matrix,
            rois[roi_id],
            samples_per_mm=fixture["samples_per_mm"],
            trim_fraction=fixture["trim_fraction"],
        )
        samples[roi_id] = actual
        cmp.close(f"roi[{roi_id}].requested_samples",
                  actual["requested_samples"], expected["requested_samples"], 0)
        cmp.close(f"roi[{roi_id}].used_samples", actual["used_samples"],
                  expected["used_samples"], 0)
        for key in ("trimmed_mean_linear", "median_linear", "lab",
                    "standard_deviation_linear"):
            cmp.close(f"roi[{roi_id}].{key}", actual[key], expected[key],
                      tol["statistics_absolute"])

    # --- reference correction --------------------------------------------
    correction = cases["reference_correction"]
    printed = fixture["printed_colours_srgb8"]

    def target(patch_id):
        c = printed[patch_id]
        return [ref.linearise(v / 255.0) for v in c]

    fit_pairs = [
        (samples[pid]["trimmed_mean_linear"], target(pid))
        for pid in fixture["fit_patch_ids"]
    ]
    fitted = ref.fit_correction(fit_pairs, form=correction["form"])
    for r in range(len(fitted)):
        cmp.close(f"correction.matrix[{r}]", fitted[r],
                  correction["expected_matrix"][r], tol["statistics_absolute"])

    corrected = ref.apply_correction(
        fitted, samples["A1"]["trimmed_mean_linear"], form=correction["form"]
    )
    cmp.close("correction.corrected_sensor_a1", corrected,
              correction["expected_corrected_sensor_a1"],
              tol["statistics_absolute"])

    for expected in correction["expected_holdout_residuals"]:
        pid = expected["patch_id"]
        corrected_patch = ref.apply_correction(
            fitted, samples[pid]["trimmed_mean_linear"], form=correction["form"]
        )
        corrected_lab = ref.xyz_to_lab(*ref.linear_to_xyz(*corrected_patch))
        target_lab = ref.xyz_to_lab(*ref.linear_to_xyz(*target(pid)))
        cmp.close(f"correction.holdout[{pid}].delta_e00",
                  ref.delta_e2000(corrected_lab, target_lab),
                  expected["delta_e00"], tol["delta_e_absolute"])
        cmp.close(f"correction.holdout[{pid}].delta_e76",
                  ref.delta_e76(corrected_lab, target_lab),
                  expected["delta_e76"], tol["delta_e_absolute"])

    # --- image quality ----------------------------------------------------
    quality = cases["image_quality"]
    actual_quality = ref.measure_image_quality(image)
    for key in ("laplacian_variance", "high_clip_fraction", "low_clip_fraction",
                "specular_fraction", "luma_mean", "luma_median"):
        cmp.close(f"quality.{key}", actual_quality[key],
                  quality[f"expected_{key}"], tol["quality_absolute"])

    # --- M0B: correction conditioning -------------------------------------
    for name, case in cases["correction_conditioning"].items():
        actual = ref.correction_conditioning(case["measured"])
        cmp.close(f"conditioning[{name}].eigenvalues", actual["eigenvalues"],
                  case["expected_eigenvalues"], tol["statistics_absolute"])
        cmp.close(f"conditioning[{name}].effective_rank",
                  actual["effective_rank"], case["expected_effective_rank"], 0)
        cmp.close(f"conditioning[{name}].is_full_rank",
                  actual["is_full_rank"], case["expected_is_full_rank"], 0)
        expected_condition = case["expected_condition_number"]
        if expected_condition is None:
            # Null means "not finite", which is itself the finding.
            cmp.close(f"conditioning[{name}].condition_is_finite",
                      math.isfinite(actual["condition_number"]), False, 0)
        else:
            cmp.close(f"conditioning[{name}].condition_number",
                      actual["condition_number"], expected_condition,
                      max(tol["statistics_absolute"],
                          abs(expected_condition) * 1e-9))

    # --- M0B: geometry residuals ------------------------------------------
    geometry = cases["geometry_residuals"]
    cmp.close("geometry_residuals.magnitudes",
              ref.residual_magnitudes(geometry["predicted_px"],
                                      geometry["observed_px"]),
              geometry["expected_magnitudes_px"], tol["homography_absolute"])

    # --- M0B: monotonicity -------------------------------------------------
    mono = cases["monotonicity"]
    offset = mono["replicate_offset"]
    # Reconstruct the same three replicates per level the generator used.
    spreads = []
    for _ in mono["means"]:
        replicates = [-offset, 0.0, offset]
        mean = sum(replicates) / 3
        spreads.append(
            math.sqrt(sum((v - mean) ** 2 for v in replicates) / 2)
        )
    actual_mono = ref.analyse_monotonicity(mono["doses"], mono["means"], spreads)
    cmp.close("monotonicity.spearman_rho", actual_mono["spearman_rho"],
              mono["expected_spearman_rho"], tol["statistics_absolute"])
    cmp.close("monotonicity.direction",
              actual_mono["direction"] == mono["expected_direction"], True, 0)
    cmp.close("monotonicity.significant_reversals",
              actual_mono["significant_reversals"],
              mono["expected_significant_reversals"], 0)
    cmp.close("monotonicity.largest_reversal", actual_mono["largest_reversal"],
              mono["expected_largest_reversal"], tol["statistics_absolute"])
    cmp.close("monotonicity.monotonic_domain",
              actual_mono["monotonic_domain"],
              mono["expected_monotonic_domain"], tol["statistics_absolute"])
    expected_separation = mono["expected_minimum_separation_ratio"]
    if expected_separation is None:
        cmp.close("monotonicity.separation_is_finite",
                  math.isfinite(actual_mono["minimum_separation_ratio"]),
                  False, 0)
    else:
        cmp.close("monotonicity.minimum_separation_ratio",
                  actual_mono["minimum_separation_ratio"], expected_separation,
                  tol["statistics_absolute"])

    # --- report ------------------------------------------------------------
    print(f"feature definition: {vectors['feature_definition_version']}")
    print(f"data domain:        {vectors['data_domain']} "
          f"({vectors['disclosure']})")
    print(f"comparisons:        {cmp.checked}")

    if cmp.failures:
        print(f"\nDIVERGENCE: {len(cmp.failures)} comparison(s) failed\n",
              file=sys.stderr)
        for failure in cmp.failures[:40]:
            print(f"  {failure}", file=sys.stderr)
        if len(cmp.failures) > 40:
            print(f"  ... and {len(cmp.failures) - 40} more", file=sys.stderr)
        return 1

    print("\nPython matches the golden vectors on every comparison.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
