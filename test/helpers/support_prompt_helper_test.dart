import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/support_prompt_helper.dart';

void main() {
  group('SupportPromptHelper.decide', () {
    test('first-ever launch (no stored timestamp) seeds but does not show', () {
      final SupportPromptDecision decision =
          SupportPromptHelper.decide(lastShownMillis: null, nowMillis: 1700000000000);
      expect(decision.shouldShow, isFalse);
      expect(decision.newLastShownMillis, 1700000000000);
    });

    test('less than a week since last shown -> does nothing', () {
      const int now = 1700000000000;
      final int lastShown = now - (SupportPromptHelper.kWeekMillis - 1000); // 1s inside
      final SupportPromptDecision decision =
          SupportPromptHelper.decide(lastShownMillis: lastShown, nowMillis: now);
      expect(decision.shouldShow, isFalse);
      expect(decision.newLastShownMillis, isNull);
    });

    test('exactly a week since last shown -> shows (boundary inclusive)', () {
      const int now = 1700000000000;
      final int lastShown = now - SupportPromptHelper.kWeekMillis;
      final SupportPromptDecision decision =
          SupportPromptHelper.decide(lastShownMillis: lastShown, nowMillis: now);
      expect(decision.shouldShow, isTrue);
      expect(decision.newLastShownMillis, now);
    });

    test('more than a week since last shown -> shows and refreshes the timestamp', () {
      const int now = 1700000000000;
      final int lastShown = now - SupportPromptHelper.kWeekMillis - 1000;
      final SupportPromptDecision decision =
          SupportPromptHelper.decide(lastShownMillis: lastShown, nowMillis: now);
      expect(decision.shouldShow, isTrue);
      expect(decision.newLastShownMillis, now);
    });
  });
}
