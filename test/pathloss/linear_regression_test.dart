import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/pathloss/linear_regression.dart';

/// Deterministic checks for the ordinary-least-squares solver.
///
/// Ported from the Java `LinearRegressionTest`.
void main() {
  group('LinearRegressionTest', () {
    test('fitsExactLinearRelationship', () {
      // y = 2 + 3*x1 - 1*x2
      List<List<double>> x = List.generate(200, (_) => List.filled(3, 0.0));
      List<double> y = List.filled(200, 0.0);
      Random r = Random(42);
      for (int i = 0; i < 200; i++) {
        x[i][0] = 1.0;
        x[i][1] = r.nextDouble() * 10;
        x[i][2] = r.nextDouble() * 5;
        y[i] = 2 + 3 * x[i][1] - 1 * x[i][2];
      }
      List<double> beta = LinearRegression.fit(x, y);
      expect(beta[0], closeTo(2.0, 1e-9));
      expect(beta[1], closeTo(3.0, 1e-9));
      expect(beta[2], closeTo(-1.0, 1e-9));
      expect(LinearRegression.rSquared(x, y, beta), closeTo(1.0, 1e-9));
    });

    test('fitsWithNoise', () {
      List<List<double>> x = List.generate(500, (_) => List.filled(2, 0.0));
      List<double> y = List.filled(500, 0.0);
      Random r = Random(7);
      for (int i = 0; i < 500; i++) {
        x[i][0] = 1.0;
        x[i][1] = r.nextDouble() * 100;
        y[i] = 5 + 2.5 * x[i][1] + (r.nextDouble() - 0.5); // small noise
      }
      List<double> beta = LinearRegression.fit(x, y);
      expect(beta[0], closeTo(5.0, 0.05));
      expect(beta[1], closeTo(2.5, 0.01));
      expect(LinearRegression.rSquared(x, y, beta), closeTo(1.0, 0.001));
    });

    test('rejectsSingularMatrix', () {
      List<List<double>> x = [
        [1.0, 2.0],
        [2.0, 4.0]
      ]; // columns linearly dependent
      List<double> y = [1.0, 2.0];
      expect(() => LinearRegression.fit(x, y), throwsArgumentError);
    });
  });
}
