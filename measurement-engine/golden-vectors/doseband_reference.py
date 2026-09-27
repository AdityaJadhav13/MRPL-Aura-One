"""Reference implementation of the DoseBand optical primitives, in Python.

This is the research-stack half of the cross-language contract described in
README.md. It deliberately uses **only the standard library**: no numpy, no
OpenCV, no scikit-image.

That is not minimalism for its own sake. The purpose of this file is to be an
independent implementation of the same arithmetic as
`measurement-engine/lib/src/`. If it delegated the linear algebra and the
colour conversions to a third-party library, the two stacks would agree
because they were both calling the same C code, and the test would stop
detecting the thing it exists to detect: that our Dart implementation and our
Python analysis compute the same numbers.

Where the research notebooks later want numpy, they should import *this* module
for the primitives and use numpy for everything downstream of them.
"""

from __future__ import annotations

import math
from typing import Iterable, Sequence

# --------------------------------------------------------------------------
# Colour science
# --------------------------------------------------------------------------

LINEAR_RGB_TO_XYZ = (
    (0.4124564, 0.3575761, 0.1804375),
    (0.2126729, 0.7151522, 0.0721750),
    (0.0193339, 0.1191920, 0.9503041),
)

# Row sums of the matrix above, NOT the rounded CIE table values. See the
# commentary on d65TwoDegree in colour_types.dart: the published matrix does
# not sum to unity in Y, and using 1.0 here would put a permanent offset on
# every delta-E.
D65_XN = 0.95047
D65_YN = 1.0000001
D65_ZN = 1.08883

_DELTA = 6.0 / 29.0
_DELTA_CUBED = _DELTA ** 3
_THREE_DELTA_SQUARED = 3.0 * _DELTA * _DELTA


def linearise(channel: float) -> float:
    sign = -1.0 if channel < 0 else 1.0
    c = abs(channel)
    if c <= 0.04045:
        return sign * (c / 12.92)
    return sign * ((c + 0.055) / 1.055) ** 2.4


def delinearise(channel: float) -> float:
    sign = -1.0 if channel < 0 else 1.0
    c = abs(channel)
    if c <= 0.0031308:
        return sign * (c * 12.92)
    return sign * (1.055 * (c ** (1.0 / 2.4)) - 0.055)


def linear_to_xyz(r: float, g: float, b: float) -> tuple[float, float, float]:
    m = LINEAR_RGB_TO_XYZ
    return (
        m[0][0] * r + m[0][1] * g + m[0][2] * b,
        m[1][0] * r + m[1][1] * g + m[1][2] * b,
        m[2][0] * r + m[2][1] * g + m[2][2] * b,
    )


def _f(t: float) -> float:
    if t > _DELTA_CUBED:
        return t ** (1.0 / 3.0)
    return t / _THREE_DELTA_SQUARED + 4.0 / 29.0


def xyz_to_lab(x: float, y: float, z: float) -> tuple[float, float, float]:
    fx = _f(x / D65_XN)
    fy = _f(y / D65_YN)
    fz = _f(z / D65_ZN)
    return (116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


def srgb_to_lab(r: float, g: float, b: float) -> tuple[float, float, float]:
    lin = (linearise(r), linearise(g), linearise(b))
    return xyz_to_lab(*linear_to_xyz(*lin))


def delta_e76(lab1: Sequence[float], lab2: Sequence[float]) -> float:
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(lab1, lab2)))


def delta_e2000(
    lab1: Sequence[float],
    lab2: Sequence[float],
    k_l: float = 1.0,
    k_c: float = 1.0,
    k_h: float = 1.0,
) -> float:
    """CIEDE2000, per Sharma, Wu and Dalal (2005).

    Mirrors delta_e.dart line for line, including the hue edge cases.
    """
    l1, a1, b1 = lab1
    l2, a2, b2 = lab2

    c1ab = math.hypot(a1, b1)
    c2ab = math.hypot(a2, b2)
    cbar_ab = (c1ab + c2ab) / 2.0

    cbar_ab7 = cbar_ab ** 7
    g = 0.5 * (1.0 - math.sqrt(cbar_ab7 / (cbar_ab7 + 6103515625.0)))

    a1p = (1.0 + g) * a1
    a2p = (1.0 + g) * a2
    c1p = math.hypot(a1p, b1)
    c2p = math.hypot(a2p, b2)

    def hue(bb: float, ap: float) -> float:
        if bb == 0.0 and ap == 0.0:
            return 0.0
        h = math.degrees(math.atan2(bb, ap))
        return h + 360.0 if h < 0 else h

    h1p = hue(b1, a1p)
    h2p = hue(b2, a2p)

    dlp = l2 - l1
    dcp = c2p - c1p

    chroma_product = c1p * c2p
    if chroma_product == 0.0:
        dhp = 0.0
    else:
        diff = h2p - h1p
        if abs(diff) <= 180.0:
            dhp = diff
        elif diff > 180.0:
            dhp = diff - 360.0
        else:
            dhp = diff + 360.0
    dhp_cap = 2.0 * math.sqrt(chroma_product) * math.sin(math.radians(dhp / 2.0))

    lbar_p = (l1 + l2) / 2.0
    cbar_p = (c1p + c2p) / 2.0

    if chroma_product == 0.0:
        hbar_p = h1p + h2p
    else:
        total = h1p + h2p
        if abs(h1p - h2p) <= 180.0:
            hbar_p = total / 2.0
        elif total < 360.0:
            hbar_p = (total + 360.0) / 2.0
        else:
            hbar_p = (total - 360.0) / 2.0

    t = (
        1.0
        - 0.17 * math.cos(math.radians(hbar_p - 30.0))
        + 0.24 * math.cos(math.radians(2.0 * hbar_p))
        + 0.32 * math.cos(math.radians(3.0 * hbar_p + 6.0))
        - 0.20 * math.cos(math.radians(4.0 * hbar_p - 63.0))
    )

    d_theta = 30.0 * math.exp(-(((hbar_p - 275.0) / 25.0) ** 2))
    cbar_p7 = cbar_p ** 7
    r_c = 2.0 * math.sqrt(cbar_p7 / (cbar_p7 + 6103515625.0))
    r_t = -math.sin(math.radians(2.0 * d_theta)) * r_c

    lbar_minus_50_sq = (lbar_p - 50.0) ** 2
    s_l = 1.0 + (0.015 * lbar_minus_50_sq) / math.sqrt(20.0 + lbar_minus_50_sq)
    s_c = 1.0 + 0.045 * cbar_p
    s_h = 1.0 + 0.015 * cbar_p * t

    term_l = dlp / (k_l * s_l)
    term_c = dcp / (k_c * s_c)
    term_h = dhp_cap / (k_h * s_h)

    return math.sqrt(
        term_l * term_l + term_c * term_c + term_h * term_h
        + r_t * term_c * term_h
    )


def qrsens_normalise(
    sensor: Sequence[float],
    black: Sequence[float],
    white: Sequence[float],
    form: str,
    scale: float = 1.0,
    minimum_denominator: float = 1e-4,
) -> list[float] | None:
    """QRsens Eq. 1 / Eq. 2. Returns None when a denominator collapses."""
    if form == "equation_1":
        denominators = list(white)
    elif form == "equation_2":
        denominators = [w - b for w, b in zip(white, black)]
    else:
        raise ValueError(f"unknown form {form!r}")

    if any(abs(d) <= minimum_denominator for d in denominators):
        return None
    return [
        scale * (s - b) / d for s, b, d in zip(sensor, black, denominators)
    ]


# --------------------------------------------------------------------------
# Statistics
# --------------------------------------------------------------------------


def percentile(sorted_values: Sequence[float], fraction: float) -> float:
    """numpy's default 'linear' method, restated so the convention is ours."""
    if not sorted_values:
        raise ValueError("percentile of an empty sample")
    if len(sorted_values) == 1:
        return sorted_values[0]
    position = fraction * (len(sorted_values) - 1)
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return sorted_values[lower]
    weight = position - lower
    return sorted_values[lower] * (1 - weight) + sorted_values[upper] * weight


def summarise(values: Iterable[float], trim_fraction: float = 0.1) -> dict:
    s = sorted(values)
    n = len(s)
    if n == 0:
        raise ValueError("cannot summarise an empty sample")

    mean = sum(s) / n
    # Sample standard deviation (n - 1), matching statistics.dart.
    if n > 1:
        variance_sum = sum((v - mean) ** 2 for v in s)
        standard_deviation = math.sqrt(variance_sum / (n - 1))
    else:
        standard_deviation = 0.0

    cut = math.floor(n * trim_fraction)
    trimmed = s[cut:n - cut] if (n - 2 * cut) > 0 else s

    return {
        "count": n,
        "mean": mean,
        "median": percentile(s, 0.5),
        "trimmed_mean": sum(trimmed) / len(trimmed),
        "standard_deviation": standard_deviation,
        "p25": percentile(s, 0.25),
        "p75": percentile(s, 0.75),
        "minimum": s[0],
        "maximum": s[-1],
    }


# --------------------------------------------------------------------------
# Linear algebra
# --------------------------------------------------------------------------


def solve(a: list[list[float]], b: list[list[float]],
          minimum_pivot: float = 1e-12) -> list[list[float]]:
    """Gauss-Jordan with partial pivoting. Mirrors matrix.dart."""
    n = len(a)
    cols_b = len(b[0])
    aug = [list(a[r]) + list(b[r]) for r in range(n)]

    for col in range(n):
        pivot_row = col
        best = abs(aug[col][col])
        for r in range(col + 1, n):
            if abs(aug[r][col]) > best:
                best = abs(aug[r][col])
                pivot_row = r
        if best <= minimum_pivot:
            raise ValueError(f"no usable pivot in column {col}")
        if pivot_row != col:
            aug[col], aug[pivot_row] = aug[pivot_row], aug[col]
        pivot = aug[col][col]
        aug[col] = [v / pivot for v in aug[col]]
        for r in range(n):
            if r == col:
                continue
            factor = aug[r][col]
            if factor == 0.0:
                continue
            aug[r] = [v - factor * p for v, p in zip(aug[r], aug[col])]

    return [row[n:n + cols_b] for row in aug]


def symmetric_eigen(input_matrix: list[list[float]], max_sweeps: int = 100,
                    tolerance: float = 1e-14):
    """Cyclic Jacobi. Mirrors symmetricEigen in matrix.dart, including the
    ascending sort and the eigenvector sign stabilisation."""
    n = len(input_matrix)
    a = [list(row) for row in input_matrix]
    v = [[1.0 if i == j else 0.0 for j in range(n)] for i in range(n)]

    def off_diagonal_norm() -> float:
        total = 0.0
        for r in range(n):
            for c in range(r + 1, n):
                total += a[r][c] * a[r][c]
        return math.sqrt(2.0 * total)

    for _ in range(max_sweeps):
        if off_diagonal_norm() <= tolerance:
            break
        for p in range(n - 1):
            for q in range(p + 1, n):
                apq = a[p][q]
                if abs(apq) <= tolerance:
                    continue
                theta = (a[q][q] - a[p][p]) / (2.0 * apq)
                if theta >= 0:
                    t = 1.0 / (theta + math.sqrt(1.0 + theta * theta))
                else:
                    t = -1.0 / (-theta + math.sqrt(1.0 + theta * theta))
                c = 1.0 / math.sqrt(1.0 + t * t)
                s = t * c

                for k in range(n):
                    akp, akq = a[k][p], a[k][q]
                    a[k][p] = c * akp - s * akq
                    a[k][q] = s * akp + c * akq
                for k in range(n):
                    apk, aqk = a[p][k], a[q][k]
                    a[p][k] = c * apk - s * aqk
                    a[q][k] = s * apk + c * aqk
                for k in range(n):
                    vkp, vkq = v[k][p], v[k][q]
                    v[k][p] = c * vkp - s * vkq
                    v[k][q] = s * vkp + c * vkq

    order = sorted(range(n), key=lambda i: a[i][i])
    values = [a[i][i] for i in order]
    vectors = [[0.0] * n for _ in range(n)]
    for c, src in enumerate(order):
        sign = 1.0
        for r in range(n):
            if abs(v[r][src]) > 1e-12:
                sign = -1.0 if v[r][src] < 0 else 1.0
                break
        for r in range(n):
            vectors[r][c] = sign * v[r][src]
    return values, vectors


def _normalise(points: Sequence[Sequence[float]]):
    n = len(points)
    cx = sum(p[0] for p in points) / n
    cy = sum(p[1] for p in points) / n
    mean_distance = sum(math.hypot(p[0] - cx, p[1] - cy) for p in points) / n
    if mean_distance < 1e-12:
        return None
    s = math.sqrt(2) / mean_distance
    transform = [[s, 0.0, -s * cx], [0.0, s, -s * cy], [0.0, 0.0, 1.0]]
    normalised = [[s * (p[0] - cx), s * (p[1] - cy)] for p in points]
    return normalised, transform


def _matmul(a, b):
    rows, inner, cols = len(a), len(b), len(b[0])
    out = [[0.0] * cols for _ in range(rows)]
    for r in range(rows):
        for k in range(inner):
            if a[r][k] == 0.0:
                continue
            for c in range(cols):
                out[r][c] += a[r][k] * b[k][c]
    return out


def _invert3(m):
    a, b, c = m[0]
    d, e, f = m[1]
    g, h, i = m[2]
    det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    if abs(det) < 1e-15:
        raise ValueError("matrix is not invertible")
    return [
        [(e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det],
        [(f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det],
        [(d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det],
    ]


def estimate_homography(correspondences, minimum_null_space_margin: float = 1e-9):
    """Normalised DLT. Mirrors estimateHomography in homography.dart.

    `correspondences` is a sequence of ((badge_x, badge_y), (image_x, image_y)).
    """
    if len(correspondences) < 4:
        raise ValueError("need at least 4 correspondences")

    badge_norm = _normalise([c[0] for c in correspondences])
    image_norm = _normalise([c[1] for c in correspondences])
    if badge_norm is None or image_norm is None:
        raise ValueError("all points are coincident")
    badge_points, badge_transform = badge_norm
    image_points, image_transform = image_norm

    a = []
    for (sx, sy), (dx, dy) in zip(badge_points, image_points):
        a.append([-sx, -sy, -1.0, 0.0, 0.0, 0.0, sx * dx, sy * dx, dx])
        a.append([0.0, 0.0, 0.0, -sx, -sy, -1.0, sx * dy, sy * dy, dy])

    at = [[a[r][c] for r in range(len(a))] for c in range(9)]
    ata = _matmul(at, a)
    values, vectors = symmetric_eigen(ata)

    largest = abs(values[-1])
    if largest < 1e-300:
        raise ValueError("design matrix is entirely zero")
    margin = abs(values[1]) / largest
    if margin < minimum_null_space_margin:
        raise ValueError(f"degenerate correspondences (margin {margin})")

    h = [vectors[r][0] for r in range(9)]
    h_norm = [h[0:3], h[3:6], h[6:9]]

    denormalised = _matmul(_matmul(_invert3(image_transform), h_norm),
                           badge_transform)
    scale = denormalised[2][2]
    if abs(scale) < 1e-15:
        raise ValueError("homography has a vanishing scale term")
    return [[v / scale for v in row] for row in denormalised], margin


def map_point(h, x: float, y: float) -> tuple[float, float]:
    w = h[2][0] * x + h[2][1] * y + h[2][2]
    if w == 0.0:
        raise ValueError("point maps to infinity")
    return (
        (h[0][0] * x + h[0][1] * y + h[0][2]) / w,
        (h[1][0] * x + h[1][1] * y + h[1][2]) / w,
    )


def reprojection_rms(h, correspondences) -> float:
    total = 0.0
    for (bx, by), (ix, iy) in correspondences:
        px, py = map_point(h, bx, by)
        total += (px - ix) ** 2 + (py - iy) ** 2
    return math.sqrt(total / len(correspondences))


# --------------------------------------------------------------------------
# Images
# --------------------------------------------------------------------------


class PpmImage:
    """Binary PPM (P6). Twenty lines, no dependency, byte-exact."""

    __slots__ = ("width", "height", "data")

    def __init__(self, width: int, height: int, data: bytes):
        self.width = width
        self.height = height
        self.data = data

    @classmethod
    def load(cls, path: str) -> "PpmImage":
        with open(path, "rb") as handle:
            raw = handle.read()

        offset = 0

        def next_token() -> str:
            nonlocal offset
            while offset < len(raw):
                byte = raw[offset]
                if byte == 0x23:  # '#'
                    while offset < len(raw) and raw[offset] != 0x0A:
                        offset += 1
                elif byte in (0x20, 0x09, 0x0A, 0x0D):
                    offset += 1
                else:
                    break
            start = offset
            while offset < len(raw) and raw[offset] not in (0x20, 0x09, 0x0A, 0x0D):
                offset += 1
            if start == offset:
                raise ValueError("truncated PPM header")
            return raw[start:offset].decode("ascii")

        magic = next_token()
        if magic != "P6":
            raise ValueError(f'expected P6 PPM, found "{magic}"')
        width = int(next_token())
        height = int(next_token())
        max_value = int(next_token())
        if max_value != 255:
            raise ValueError(f"only 8-bit PPM is supported, found {max_value}")
        offset += 1

        expected = width * height * 3
        if len(raw) - offset < expected:
            raise ValueError("truncated PPM raster")
        return cls(width, height, raw[offset:offset + expected])

    def channel(self, x: int, y: int, c: int) -> int:
        return self.data[(y * self.width + x) * 3 + c]

    def luma(self, x: int, y: int) -> float:
        i = (y * self.width + x) * 3
        return (
            0.2126 * self.data[i]
            + 0.7152 * self.data[i + 1]
            + 0.0722 * self.data[i + 2]
        ) / 255.0

    def sample_bilinear(self, x: float, y: float):
        if x < 0 or y < 0 or x > self.width - 1 or y > self.height - 1:
            return None
        x0 = math.floor(x)
        y0 = math.floor(y)
        x1 = x0 if x0 + 1 > self.width - 1 else x0 + 1
        y1 = y0 if y0 + 1 > self.height - 1 else y0 + 1
        fx = x - x0
        fy = y - y0

        out = []
        for c in range(3):
            top = self.channel(x0, y0, c) * (1 - fx) + self.channel(x1, y0, c) * fx
            bottom = self.channel(x0, y1, c) * (1 - fx) + self.channel(x1, y1, c) * fx
            out.append((top * (1 - fy) + bottom * fy) / 255.0)
        return out


def sample_roi(
    image: PpmImage,
    badge_to_image,
    roi: dict,
    samples_per_mm: float = 20.0,
    trim_fraction: float = 0.1,
    clip_high: float = 0.99,
    clip_low: float = 0.01,
    specular_luma: float = 0.95,
    specular_chroma: float = 0.06,
) -> dict:
    """Mirrors sampleRoi in roi_sample.dart, erosion and guards included."""
    erosion = roi.get("erosion_mm", 0.5)
    x_mm = roi["x_mm"] + erosion
    y_mm = roi["y_mm"] + erosion
    width_mm = roi["width_mm"] - 2 * erosion
    height_mm = roi["height_mm"] - 2 * erosion
    if width_mm <= 0 or height_mm <= 0:
        raise ValueError(f"ROI {roi['id']} is consumed by its erosion margin")

    columns = math.floor(width_mm * samples_per_mm)
    rows = math.floor(height_mm * samples_per_mm)

    channels: list[list[float]] = [[], [], []]
    exclusions = {"outOfFrame": 0, "clipped": 0, "specular": 0}

    for row in range(rows):
        y = y_mm + (row + 0.5) / samples_per_mm
        for col in range(columns):
            x = x_mm + (col + 0.5) / samples_per_mm
            try:
                px, py = map_point(badge_to_image, x, y)
            except ValueError:
                exclusions["outOfFrame"] += 1
                continue
            srgb = image.sample_bilinear(px, py)
            if srgb is None:
                exclusions["outOfFrame"] += 1
                continue

            max_channel = max(srgb)
            min_channel = min(srgb)
            if max_channel >= clip_high or min_channel <= clip_low:
                exclusions["clipped"] += 1
                continue
            luma = 0.2126 * srgb[0] + 0.7152 * srgb[1] + 0.0722 * srgb[2]
            if luma >= specular_luma and (max_channel - min_channel) <= specular_chroma:
                exclusions["specular"] += 1
                continue

            for c in range(3):
                channels[c].append(linearise(srgb[c]))

    if not channels[0]:
        raise ValueError(f"no usable samples in ROI {roi['id']}")

    stats = [summarise(c, trim_fraction=trim_fraction) for c in channels]
    trimmed = [s["trimmed_mean"] for s in stats]
    median = [s["median"] for s in stats]
    return {
        "requested_samples": rows * columns,
        "used_samples": len(channels[0]),
        "exclusions": exclusions,
        "trimmed_mean_linear": trimmed,
        "median_linear": median,
        "lab": list(xyz_to_lab(*linear_to_xyz(*trimmed))),
        "standard_deviation_linear": [s["standard_deviation"] for s in stats],
    }


def measure_image_quality(
    image: PpmImage,
    clip_high: float = 0.99,
    clip_low: float = 0.01,
    specular_luma: float = 0.95,
    specular_chroma: float = 0.06,
) -> dict:
    """Mirrors measureImageQuality in image_quality.dart."""
    high_clipped = 0
    low_clipped = 0
    specular = 0
    luma_values: list[float] = []
    laplacian_values: list[float] = []

    width, height = image.width, image.height
    for y in range(height):
        for x in range(width):
            i = (y * width + x) * 3
            rr = image.data[i] / 255.0
            gg = image.data[i + 1] / 255.0
            bb = image.data[i + 2] / 255.0
            max_channel = max(rr, gg, bb)
            min_channel = min(rr, gg, bb)
            if max_channel >= clip_high:
                high_clipped += 1
            if min_channel <= clip_low:
                low_clipped += 1

            l = image.luma(x, y)
            luma_values.append(l)
            if l >= specular_luma and (max_channel - min_channel) <= specular_chroma:
                specular += 1

            if 0 < x < width - 1 and 0 < y < height - 1:
                laplacian_values.append(
                    image.luma(x - 1, y)
                    + image.luma(x + 1, y)
                    + image.luma(x, y - 1)
                    + image.luma(x, y + 1)
                    - 4.0 * l
                )

    count = len(luma_values)
    # Population variance (divide by n), matching image_quality.dart.
    if len(laplacian_values) > 1:
        mean = sum(laplacian_values) / len(laplacian_values)
        laplacian_variance = sum((v - mean) ** 2 for v in laplacian_values) / len(
            laplacian_values
        )
    else:
        laplacian_variance = float("nan")

    luma_stats = summarise(luma_values, trim_fraction=0)
    return {
        "laplacian_variance": laplacian_variance,
        "high_clip_fraction": high_clipped / count,
        "low_clip_fraction": low_clipped / count,
        "specular_fraction": specular / count,
        "luma_mean": luma_stats["mean"],
        "luma_median": luma_stats["median"],
    }


# --------------------------------------------------------------------------
# Reference correction
# --------------------------------------------------------------------------


def fit_correction(fit_patches, form: str = "affine3x4"):
    """Least squares M = (X^T X)^-1 X^T Y. Mirrors fitCorrection."""
    parameters = 3 if form == "linear3x3" else 4
    if len(fit_patches) < parameters:
        raise ValueError(f"{form} needs at least {parameters} patches")

    x = []
    y = []
    for measured, target in fit_patches:
        row = list(measured)
        if parameters == 4:
            row.append(1.0)
        x.append(row)
        y.append(list(target))

    xt = [[x[r][c] for r in range(len(x))] for c in range(parameters)]
    return solve(_matmul(xt, x), _matmul(xt, y))


def apply_correction(matrix, value, form: str = "affine3x4"):
    row = list(value) + ([1.0] if form == "affine3x4" else [])
    return [
        sum(row[i] * matrix[i][c] for i in range(len(row))) for c in range(3)
    ]


# --------------------------------------------------------------------------
# M0B: conditioning, geometry residuals, monotonicity
# --------------------------------------------------------------------------


def correction_conditioning(measured, form: str = "affine3x4",
                            rank_tolerance: float = 1e-10):
    """Eigen-analysis of X^T X. Mirrors fitCorrection's conditioning block.

    Inspecting conditioning BEFORE solving is the point: a singular system
    throws and is noticed, while a merely ill-conditioned one solves quietly
    and is wrong.
    """
    parameters = 3 if form == "linear3x3" else 4
    x = [list(m) + ([1.0] if parameters == 4 else []) for m in measured]
    xt = [[x[r][c] for r in range(len(x))] for c in range(parameters)]
    normal = _matmul(xt, x)
    values, _ = symmetric_eigen(normal)

    largest = abs(values[-1])
    smallest = abs(values[0])
    condition = float("inf") if smallest <= 0 else largest / smallest
    effective_rank = (
        0 if largest <= 0
        else sum(1 for v in values if abs(v) / largest > rank_tolerance)
    )
    return {
        "eigenvalues": values,
        "condition_number": condition,
        "effective_rank": effective_rank,
        "parameters": parameters,
        "is_full_rank": effective_rank >= parameters,
    }


def residual_magnitudes(predicted_px, observed_px) -> list[float]:
    return [
        math.hypot(o[0] - p[0], o[1] - p[1])
        for p, o in zip(predicted_px, observed_px)
    ]


def _ranks(values: Sequence[float]) -> list[float]:
    """Average ranks, ties sharing the mean of the ranks they span."""
    indexed = sorted(range(len(values)), key=lambda i: values[i])
    ranks = [0.0] * len(values)
    i = 0
    while i < len(indexed):
        j = i
        while j + 1 < len(indexed) and values[indexed[j + 1]] == values[indexed[i]]:
            j += 1
        average = (i + j) / 2.0 + 1.0
        for k in range(i, j + 1):
            ranks[indexed[k]] = average
        i = j + 1
    return ranks


def _pearson(a: Sequence[float], b: Sequence[float]) -> float:
    n = len(a)
    if n < 2:
        return float("nan")
    mean_a = sum(a) / n
    mean_b = sum(b) / n
    num = sum((a[i] - mean_a) * (b[i] - mean_b) for i in range(n))
    den_a = sum((v - mean_a) ** 2 for v in a)
    den_b = sum((v - mean_b) ** 2 for v in b)
    if den_a == 0 or den_b == 0:
        return 0.0
    return num / math.sqrt(den_a * den_b)


def analyse_monotonicity(doses: Sequence[float], means: Sequence[float],
                         spreads: Sequence[float]) -> dict:
    """Mirrors analyseMonotonicity in monotonicity.dart.

    Both increasing and decreasing responses are supported: several published
    H2S features fall with dose, and assuming "up" would report every one of
    them as broken.
    """
    rho = _pearson(_ranks(doses), _ranks(means))

    if math.isnan(rho) or abs(rho) < 0.3:
        direction = "indeterminate"
    else:
        direction = "increasing" if rho > 0 else "decreasing"
    sign = -1.0 if direction == "decreasing" else 1.0

    significant = 0
    largest_reversal = 0.0
    minimum_separation = float("inf")
    for i in range(1, len(doses)):
        step = sign * (means[i] - means[i - 1])
        pooled = math.sqrt((spreads[i] ** 2 + spreads[i - 1] ** 2) / 2)
        separation = abs(step) / pooled if pooled > 0 else float("inf")
        minimum_separation = min(minimum_separation, separation)
        if step < 0:
            magnitude = -step
            largest_reversal = max(largest_reversal, magnitude)
            if pooled <= 0 or magnitude > pooled:
                significant += 1

    best_start = best_end = run_start = 0
    for i in range(1, len(doses)):
        if sign * (means[i] - means[i - 1]) <= 0:
            run_start = i
        if i - run_start > best_end - best_start:
            best_start, best_end = run_start, i

    return {
        "spearman_rho": rho,
        "direction": direction,
        "significant_reversals": significant,
        "largest_reversal": largest_reversal,
        "monotonic_domain": [doses[best_start], doses[best_end]],
        "minimum_separation_ratio": minimum_separation,
    }
