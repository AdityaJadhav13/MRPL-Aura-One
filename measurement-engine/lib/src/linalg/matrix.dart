import 'dart:math' as math;

/// A small dense matrix of doubles, row-major.
///
/// Deliberately minimal and readable rather than fast. The pipeline's largest
/// matrix is 9x9 (the DLT normal matrix), so clarity is worth more here than
/// cache behaviour — every number in a measurement should be traceable by the
/// person defending the measurement (ADR-0003).
final class Matrix {
  Matrix(this.rows, this.cols)
    : _values = List<double>.filled(rows * cols, 0.0);

  Matrix.fromRows(List<List<double>> rowData)
    : rows = rowData.length,
      cols = rowData.isEmpty ? 0 : rowData.first.length,
      _values = <double>[for (final row in rowData) ...row] {
    for (final row in rowData) {
      if (row.length != cols) {
        throw ArgumentError('ragged matrix: expected $cols columns');
      }
    }
  }

  factory Matrix.identity(int n) {
    final m = Matrix(n, n);
    for (var i = 0; i < n; i++) {
      m.set(i, i, 1.0);
    }
    return m;
  }

  final int rows;
  final int cols;
  final List<double> _values;

  double at(int r, int c) => _values[r * cols + c];
  void set(int r, int c, double v) => _values[r * cols + c] = v;

  List<double> row(int r) => _values.sublist(r * cols, (r + 1) * cols);

  List<double> column(int c) => <double>[
    for (var r = 0; r < rows; r++) at(r, c),
  ];

  Matrix transpose() {
    final t = Matrix(cols, rows);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        t.set(c, r, at(r, c));
      }
    }
    return t;
  }

  Matrix multiply(Matrix other) {
    if (cols != other.rows) {
      throw ArgumentError(
        'cannot multiply ${rows}x$cols by ${other.rows}x${other.cols}',
      );
    }
    final out = Matrix(rows, other.cols);
    for (var r = 0; r < rows; r++) {
      for (var k = 0; k < cols; k++) {
        final a = at(r, k);
        if (a == 0.0) continue;
        for (var c = 0; c < other.cols; c++) {
          out.set(r, c, out.at(r, c) + a * other.at(k, c));
        }
      }
    }
    return out;
  }

  /// Frobenius norm.
  double get frobeniusNorm {
    var sum = 0.0;
    for (final v in _values) {
      sum += v * v;
    }
    return math.sqrt(sum);
  }

  List<List<double>> toRows() => <List<double>>[
    for (var r = 0; r < rows; r++) row(r),
  ];

  @override
  String toString() => toRows()
      .map((r) => r.map((v) => v.toStringAsFixed(6)).join(' '))
      .join('\n');
}

/// Raised when a linear system is too ill-conditioned to solve honestly.
///
/// A degenerate reference set or a collinear fiducial arrangement is a
/// detectable failure, and detecting it is the point: solving it anyway
/// produces a plausible matrix built from noise.
final class SingularSystemException implements Exception {
  const SingularSystemException(this.message, {this.pivot});

  final String message;
  final double? pivot;

  @override
  String toString() =>
      'SingularSystemException: $message'
      '${pivot == null ? '' : ' (pivot $pivot)'}';
}

/// Solves `A x = b` for several right-hand sides by Gauss-Jordan elimination
/// with partial pivoting.
///
/// [a] is n x n, [b] is n x k; returns n x k.
Matrix solve(Matrix a, Matrix b, {double minimumPivot = 1e-12}) {
  if (a.rows != a.cols) {
    throw ArgumentError('solve requires a square system');
  }
  if (a.rows != b.rows) {
    throw ArgumentError('right-hand side has the wrong number of rows');
  }

  final n = a.rows;
  final aug = Matrix(n, n + b.cols);
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      aug.set(r, c, a.at(r, c));
    }
    for (var c = 0; c < b.cols; c++) {
      aug.set(r, n + c, b.at(r, c));
    }
  }

  for (var col = 0; col < n; col++) {
    var pivotRow = col;
    var best = aug.at(col, col).abs();
    for (var r = col + 1; r < n; r++) {
      final v = aug.at(r, col).abs();
      if (v > best) {
        best = v;
        pivotRow = r;
      }
    }
    if (best <= minimumPivot) {
      throw SingularSystemException(
        'no usable pivot in column $col',
        pivot: best,
      );
    }
    if (pivotRow != col) {
      for (var c = 0; c < aug.cols; c++) {
        final tmp = aug.at(col, c);
        aug.set(col, c, aug.at(pivotRow, c));
        aug.set(pivotRow, c, tmp);
      }
    }
    final pivot = aug.at(col, col);
    for (var c = 0; c < aug.cols; c++) {
      aug.set(col, c, aug.at(col, c) / pivot);
    }
    for (var r = 0; r < n; r++) {
      if (r == col) continue;
      final factor = aug.at(r, col);
      if (factor == 0.0) continue;
      for (var c = 0; c < aug.cols; c++) {
        aug.set(r, c, aug.at(r, c) - factor * aug.at(col, c));
      }
    }
  }

  final out = Matrix(n, b.cols);
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < b.cols; c++) {
      out.set(r, c, aug.at(r, n + c));
    }
  }
  return out;
}

/// Eigen-decomposition of a real symmetric matrix by the cyclic Jacobi method.
///
/// Returns eigenvalues ascending, with `vectors.column(i)` the unit
/// eigenvector for `values[i]`.
///
/// This exists so the homography can be solved without a third-party linear
/// algebra package (ADR-0003). Jacobi is chosen over a general SVD because the
/// only matrix we need to decompose is the symmetric 9x9 `A^T A`, for which
/// Jacobi is short, unconditionally convergent and easy to test.
({List<double> values, Matrix vectors}) symmetricEigen(
  Matrix input, {
  int maxSweeps = 100,
  double tolerance = 1e-14,
}) {
  if (input.rows != input.cols) {
    throw ArgumentError('symmetricEigen requires a square matrix');
  }
  final n = input.rows;
  final a = Matrix.fromRows(input.toRows());
  final v = Matrix.identity(n);

  double offDiagonalNorm() {
    var sum = 0.0;
    for (var r = 0; r < n; r++) {
      for (var c = r + 1; c < n; c++) {
        sum += a.at(r, c) * a.at(r, c);
      }
    }
    return math.sqrt(2.0 * sum);
  }

  for (var sweep = 0; sweep < maxSweeps; sweep++) {
    if (offDiagonalNorm() <= tolerance) break;
    for (var p = 0; p < n - 1; p++) {
      for (var q = p + 1; q < n; q++) {
        final apq = a.at(p, q);
        if (apq.abs() <= tolerance) continue;

        final theta = (a.at(q, q) - a.at(p, p)) / (2.0 * apq);
        final t = theta >= 0
            ? 1.0 / (theta + math.sqrt(1.0 + theta * theta))
            : -1.0 / (-theta + math.sqrt(1.0 + theta * theta));
        final c = 1.0 / math.sqrt(1.0 + t * t);
        final s = t * c;

        for (var k = 0; k < n; k++) {
          final akp = a.at(k, p);
          final akq = a.at(k, q);
          a.set(k, p, c * akp - s * akq);
          a.set(k, q, s * akp + c * akq);
        }
        for (var k = 0; k < n; k++) {
          final apk = a.at(p, k);
          final aqk = a.at(q, k);
          a.set(p, k, c * apk - s * aqk);
          a.set(q, k, s * apk + c * aqk);
        }
        for (var k = 0; k < n; k++) {
          final vkp = v.at(k, p);
          final vkq = v.at(k, q);
          v.set(k, p, c * vkp - s * vkq);
          v.set(k, q, s * vkp + c * vkq);
        }
      }
    }
  }

  final order = <int>[for (var i = 0; i < n; i++) i]
    ..sort((x, y) => a.at(x, x).compareTo(a.at(y, y)));

  final values = <double>[for (final i in order) a.at(i, i)];
  final vectors = Matrix(n, n);
  for (var c = 0; c < n; c++) {
    final src = order[c];
    // Fix the sign so the decomposition is reproducible: the first
    // significant component of every eigenvector is made positive. Without
    // this, an eigenvector's sign is arbitrary and a golden vector comparing
    // it across two implementations would fail for no real reason.
    var sign = 1.0;
    for (var r = 0; r < n; r++) {
      final value = v.at(r, src);
      if (value.abs() > 1e-12) {
        sign = value < 0 ? -1.0 : 1.0;
        break;
      }
    }
    for (var r = 0; r < n; r++) {
      vectors.set(r, c, sign * v.at(r, src));
    }
  }
  return (values: values, vectors: vectors);
}
