import 'package:flutter_test/flutter_test.dart';
import 'package:alastudie/features/calendar/local_reminder_service.dart';

void main() {
  test('occurrence notification ids are stable and fit native id limits', () {
    final first = LocalReminderService.occurrenceReminderId('occurrence-123');
    expect(first, LocalReminderService.occurrenceReminderId('occurrence-123'));
    expect(first, greaterThan(0));
    expect(first, lessThanOrEqualTo(0x7fffffff));
    expect(
      first,
      isNot(LocalReminderService.occurrenceReminderId('occurrence-124')),
    );
  });
}
