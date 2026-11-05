import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

abstract interface class OccurrenceReminderScheduler {
  Future<bool> requestPermission();
  Future<void> syncCalendar(List<Map<String, dynamic>> occurrences);
  Future<void> cancelAllOccurrenceReminders();
}

class LocalReminderService implements OccurrenceReminderScheduler {
  LocalReminderService._();

  static final instance = LocalReminderService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return android ?? ios ?? true;
  }

  @override
  Future<void> syncCalendar(List<Map<String, dynamic>> occurrences) async {
    await initialize();
    final desired = <int, Map<String, dynamic>>{};
    final touchedIds = <String>{};
    final sorted = [...occurrences]
      ..sort(
        (a, b) => (DateTime.tryParse('${a['starts_at']}') ?? DateTime(2100))
            .compareTo(
              DateTime.tryParse('${b['starts_at']}') ?? DateTime(2100),
            ),
      );
    for (final occurrence in sorted) {
      final occurrenceId = '${occurrence['id'] ?? ''}';
      if (occurrenceId.isNotEmpty) touchedIds.add(occurrenceId);
      if (occurrence['reminder_enabled'] != true ||
          occurrence['my_rsvp'] != 'going' ||
          occurrence['status'] == 'cancelled') {
        continue;
      }
      final startsAt = DateTime.tryParse('${occurrence['starts_at']}')?.toUtc();
      if (startsAt == null || !startsAt.isAfter(DateTime.now().toUtc())) {
        continue;
      }
      if (desired.length >= 50) continue;
      desired[occurrenceReminderId(occurrenceId)] = occurrence;
    }

    final pending = await _plugin.pendingNotificationRequests();
    final managed = pending.where(
      (item) => item.payload?.startsWith('occurrence:') == true,
    );
    for (final item in managed) {
      final occurrenceId = item.payload!.substring('occurrence:'.length);
      if (touchedIds.contains(occurrenceId) && !desired.containsKey(item.id)) {
        await _plugin.cancel(id: item.id);
      }
    }

    for (final entry in desired.entries) {
      final occurrence = entry.value;
      final startsAt = DateTime.parse('${occurrence['starts_at']}').toUtc();
      final reminderAt = startsAt.subtract(const Duration(hours: 24));
      final now = DateTime.now().toUtc();
      final triggerAt = reminderAt.isAfter(now)
          ? reminderAt
          : now.add(const Duration(minutes: 1));
      if (!startsAt.isAfter(triggerAt)) {
        await _plugin.cancel(id: entry.key);
        continue;
      }
      await _plugin.zonedSchedule(
        id: entry.key,
        title: '${occurrence['room_title'] ?? 'Study room'} is coming up',
        body:
            'Your study-room meeting starts ${_relativeStart(startsAt, now)}.',
        scheduledDate: timezone.TZDateTime.from(triggerAt, timezone.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'study_room_reminders',
            'Study room reminders',
            channelDescription:
                'Reminders for study-room meetings you plan to attend.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'occurrence:${occurrence['id']}',
      );
    }
  }

  Future<void> schedulePlannerBlock(Map<String, dynamic> block) async {
    await initialize();
    final id = _plannerReminderId('${block['id'] ?? ''}');
    final startsAt = DateTime.tryParse('${block['starts_at'] ?? ''}')?.toUtc();
    if (block['reminder_enabled'] != true ||
        startsAt == null ||
        !startsAt.isAfter(DateTime.now().toUtc())) {
      await _plugin.cancel(id: id);
      return;
    }
    final reminderAt = startsAt.subtract(const Duration(minutes: 10));
    final trigger = reminderAt.isAfter(DateTime.now().toUtc())
        ? reminderAt
        : DateTime.now().toUtc().add(const Duration(minutes: 1));
    if (!startsAt.isAfter(trigger)) {
      await _plugin.cancel(id: id);
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      title: '${block['title'] ?? 'Study block'} is coming up',
      body: 'Your private study block starts in about 10 minutes.',
      scheduledDate: timezone.TZDateTime.from(trigger, timezone.UTC),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'planner_block_reminders',
          'Planner reminders',
          channelDescription: 'Reminders for private weekly study blocks.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'planner:${block['id']}',
    );
  }

  Future<void> cancelPlannerBlock(String blockId) async {
    await initialize();
    await _plugin.cancel(id: _plannerReminderId(blockId));
  }

  int _plannerReminderId(String value) {
    var hash = 0x45d9f3b;
    for (final unit in value.codeUnits) {
      hash = ((hash << 5) - hash + unit) & 0x3fffffff;
    }
    return 1_000_000_000 + hash;
  }

  @override
  Future<void> cancelAllOccurrenceReminders() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    for (final item in pending) {
      if (item.payload?.startsWith('occurrence:') == true) {
        await _plugin.cancel(id: item.id);
      }
    }
  }

  static int occurrenceReminderId(String occurrenceId) {
    var hash = 0x811c9dc5;
    for (final unit in occurrenceId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static String _relativeStart(DateTime startsAt, DateTime now) {
    final remaining = startsAt.difference(now);
    if (remaining.inDays >= 1)
      return 'in ${remaining.inDays} day${remaining.inDays == 1 ? '' : 's'}';
    if (remaining.inHours >= 1)
      return 'in ${remaining.inHours} hour${remaining.inHours == 1 ? '' : 's'}';
    return 'soon';
  }
}
