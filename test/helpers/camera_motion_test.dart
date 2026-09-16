import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/camera_motion.dart';

void main() {
  group('CameraMotion.shouldSkipAnimation', () {
    test('skips animation when disableAnimations is on', () {
      expect(CameraMotion.shouldSkipAnimation(disableAnimations: true), isTrue);
    });

    test('animates normally when disableAnimations is off', () {
      expect(
        CameraMotion.shouldSkipAnimation(disableAnimations: false),
        isFalse,
      );
    });
  });
}
