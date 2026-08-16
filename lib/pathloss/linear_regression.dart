import 'dart:math' as math;

/// Ordinary-least-squares multiple linear regression solved via the normal equations
/// (XᵀX)β = Xᵀy using Gaussian elimination with partial pivoting. Pure Dart — no external ML
/// dependency — so it runs on-device and in unit tests as well as in the trainer.
///
/// Ported from the Java `au.com.bitbot.phonetowers.pathloss.LinearRegression`.
class LinearRegression {
  LinearRegression._();

  /// Fit y = X·β by minimising Σ(yᵢ - xᵢ·β)².
  ///
  /// [x] design matrix; rows = samples, columns = features (include a constant column of 1s
  /// for the intercept). [y] response vector; length must equal the number of rows of x.
  /// Returns β coefficients, length = number of columns of x.
  static List<double> fit(List<List<double>> x, List<double> y) {
    int n = x.length;
    if (n == 0) {
      throw ArgumentError('No samples');
    }
    int k = x[0].length;
    if (y.length != n) {
      throw ArgumentError('x/y row count mismatch');
    }

    List<List<double>> xtx = List.generate(k, (_) => List.filled(k, 0.0));
    List<double> xty = List.filled(k, 0.0);
    for (int i = 0; i < n; i++) {
      for (int a = 0; a < k; a++) {
        xty[a] += x[i][a] * y[i];
        for (int b = 0; b < k; b++) {
          xtx[a][b] += x[i][a] * x[i][b];
        }
      }
    }
    return _solve(xtx, xty);
  }

  /// Solve A·x = b for square A (A is modified in place). Uses partial pivoting.
  static List<double> _solve(List<List<double>> a, List<double> b) {
    int n = b.length;
    for (int col = 0; col < n; col++) {
      int pivot = col;
      for (int r = col + 1; r < n; r++) {
        if (a[r][col].abs() > a[pivot][col].abs()) {
          pivot = r;
        }
      }
      if (a[pivot][col].abs() < 1e-12) {
        throw ArgumentError('Singular design matrix at column $col');
      }
      if (pivot != col) {
        List<double> tmp = a[pivot];
        a[pivot] = a[col];
        a[col] = tmp;
        double tb = b[pivot];
        b[pivot] = b[col];
        b[col] = tb;
      }
      for (int r = col + 1; r < n; r++) {
        double factor = a[r][col] / a[col][col];
        for (int c = col; c < n; c++) {
          a[r][c] -= factor * a[col][c];
        }
        b[r] -= factor * b[col];
      }
    }
    List<double> x = List.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      double sum = b[i];
      for (int j = i + 1; j < n; j++) {
        sum -= a[i][j] * x[j];
      }
      x[i] = sum / a[i][i];
    }
    return x;
  }

  /// Coefficient of determination R² for a fitted model.
  static double rSquared(
      List<List<double>> x, List<double> y, List<double> beta) {
    int n = y.length;
    double mean = 0;
    for (double v in y) {
      mean += v;
    }
    mean /= n;
    double ssTot = 0;
    double ssRes = 0;
    for (int i = 0; i < n; i++) {
      double pred = 0;
      for (int j = 0; j < beta.length; j++) {
        pred += x[i][j] * beta[j];
      }
      double diff = y[i] - pred;
      ssRes += diff * diff;
      double dm = y[i] - mean;
      ssTot += dm * dm;
    }
    return ssTot < 1e-12 ? 0 : 1 - ssRes / ssTot;
  }
}
