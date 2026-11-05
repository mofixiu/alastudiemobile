import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:alastudie/core/models/app_models.dart';
import 'package:alastudie/core/network/api_client.dart';
import 'package:alastudie/core/realtime/realtime_service.dart';
import 'package:alastudie/core/storage/local_store.dart';
import 'package:alastudie/features/app/app_controller.dart';
import 'package:alastudie/features/calendar/local_reminder_service.dart';

void main() {
  const user = AppUser(
    id: 'student-1',
    email: 'student@example.test',
    username: 'mofi',
  );

  test(
    'personal task checkoff is cached and queued, then reconciled online',
    () async {
      final api = _FakeApiClient();
      final local = _FakeLocalStore();
      final controller = AppController(
        api: api,
        local: local,
        realtime: _FakeRealtimeService(),
      )..currentUser = user;
      addTearDown(controller.dispose);

      final task = const StudyTask(
        id: 'personal-1',
        title: 'Read lecture notes',
        personal: true,
      );
      controller.personalTasks = [task];
      await controller.togglePersonalTask(task);

      expect(controller.personalTasks.single.completed, isTrue);
      expect(local.cache['personal_tasks'], isA<List>());
      expect(local.cache['personal_tasks'][0]['completed_at'], isNotNull);
      expect(local.outbox.single['kind'], 'personal_task');
      expect(local.outbox.single['path'], '/tasks/personal-1/completion');

      api.patchBehavior = (_, _) async => {'completed': true};
      api.getBehavior = (path) async => {
        'tasks': [
          {
            'id': 'personal-1',
            'title': 'Read lecture notes',
            'is_personal': true,
            'completed_at': '2026-10-09T12:00:00Z',
          },
        ],
      };
      await controller.syncOutbox();

      expect(local.outbox, isEmpty);
      expect(controller.personalTasks.single.completed, isTrue);
    },
  );

  test('dark appearance preference is cached on this device', () async {
    final local = _FakeLocalStore();
    final controller = AppController(
      api: _FakeApiClient(),
      local: local,
      realtime: _FakeRealtimeService(),
    );
    addTearDown(controller.dispose);

    await controller.setDarkModeEnabled(true);

    expect(controller.darkModeEnabled, isTrue);
    expect(local.cache['appearance:dark_mode'], isTrue);
  });

  test(
    'opening notifications marks visible items read and queues offline',
    () async {
      final api = _FakeApiClient();
      final local = _FakeLocalStore();
      final controller = AppController(
        api: api,
        local: local,
        realtime: _FakeRealtimeService(),
      )..currentUser = user;
      addTearDown(controller.dispose);
      controller.notifications = [
        {'id': 'notice-1', 'title': 'Room invite', 'is_read': false},
        {'id': 'notice-2', 'title': 'Already read', 'is_read': true},
        {'id': 'notice-3', 'title': 'Not opened', 'is_read': false},
      ];

      await controller.markNotificationsRead(['notice-1']);

      expect(controller.notifications[0]['is_read'], isTrue);
      expect(controller.notifications[1]['is_read'], isTrue);
      expect(controller.notifications[2]['is_read'], isFalse);
      expect(local.cache['notifications'], controller.notifications);
      expect(local.outbox.single['kind'], 'notification_read');
      expect(local.outbox.single['path'], '/notifications/notice-1/read');

      api.patchBehavior = (_, _) async => {};
      await controller.syncOutbox();
      expect(local.outbox, isEmpty);
    },
  );

  test(
    'calendar month navigation sends the visible month range to the API',
    () async {
      final api = _FakeApiClient();
      final controller = AppController(
        api: api,
        local: _FakeLocalStore(),
        realtime: _FakeRealtimeService(),
        reminders: _FakeReminderScheduler(),
      );
      addTearDown(controller.dispose);
      api.getBehavior = (_) async => {'occurrences': []};

      await controller.loadCalendar(
        from: DateTime.utc(2026, 10, 1),
        to: DateTime.utc(2026, 11, 1),
      );

      expect(api.lastQuery, {
        'from': '2026-10-01T00:00:00.000Z',
        'to': '2026-11-01T00:00:00.000Z',
      });
    },
  );

  test(
    'an RSVP still saves when notification permission is declined',
    () async {
      final api = _FakeApiClient();
      final reminders = _FakeReminderScheduler()..permissionGranted = false;
      final controller = AppController(
        api: api,
        local: _FakeLocalStore(),
        realtime: _FakeRealtimeService(),
        reminders: reminders,
      )..currentUser = user;
      addTearDown(controller.dispose);
      api.postBehavior = (_, _) async => {};
      api.getBehavior = (_) async => {'occurrences': []};

      await controller.rsvpOccurrence(
        'occurrence-1',
        status: 'going',
        reminderEnabled: true,
      );

      expect(api.lastPostedBody['reminderEnabled'], isFalse);
      expect(controller.statusMessage, contains('You’re going'));
    },
  );

  test('room presence changes immediately and is sent for the active room', () {
    final realtime = _FakeRealtimeService();
    final controller =
        AppController(
            api: _FakeApiClient(),
            local: _FakeLocalStore(),
            realtime: realtime,
          )
          ..currentUser = user
          ..activeRoomId = 'room-1';
    addTearDown(controller.dispose);

    controller.setPresence('studying');

    expect(controller.roomPresence[user.id], 'studying');
    expect(realtime.presenceUpdates, [('room-1', 'studying')]);
  });

  test('personal task creation posts then reloads the saved task', () async {
    final api = _FakeApiClient();
    final controller = AppController(
      api: api,
      local: _FakeLocalStore(),
      realtime: _FakeRealtimeService(),
    )..currentUser = user;
    addTearDown(controller.dispose);
    api.postBehavior = (path, body) async => {
      'task': {'id': 'new-task', 'title': body['title'], 'is_personal': true},
    };
    api.getBehavior = (path) async => {
      'tasks': [
        {'id': 'new-task', 'title': 'Finish notes', 'is_personal': true},
      ],
    };

    await controller.createPersonalTask('Finish notes');

    expect(api.lastPostedPath, '/tasks/personal');
    expect(controller.personalTasks.single.id, 'new-task');
    expect(controller.statusMessage, 'Added to your plan.');
    expect(controller.errorMessage, isNull);
  });

  test('room task completion survives reopening from the room cache', () async {
    final api = _FakeApiClient();
    final local = _FakeLocalStore();
    final controller =
        AppController(api: api, local: local, realtime: _FakeRealtimeService())
          ..currentUser = user
          ..activeRoomId = 'room-1'
          ..roomTasks = [
            const StudyTask(
              id: 'shared-1',
              title: 'Review the slides',
              completedCount: 1,
              memberCount: 2,
            ),
          ];
    addTearDown(controller.dispose);
    local.cache['room:room-1'] = {
      'room': {'id': 'room-1'},
      'tasks': [
        {
          'id': 'shared-1',
          'title': 'Review the slides',
          'completions': [
            {'userId': 'student-1', 'completedAt': null},
            {'userId': 'student-2', 'completedAt': '2026-10-08T10:00:00Z'},
          ],
        },
      ],
    };

    await controller.toggleRoomTask(controller.roomTasks.single);

    final cached = local.cache['room:room-1'] as Map<String, dynamic>;
    final completions = (cached['tasks'] as List).single['completions'] as List;
    expect(completions[0]['completedAt'], isNotNull);
    expect(completions[1]['completedAt'], '2026-10-08T10:00:00Z');
    expect(local.outbox.single['path'], '/tasks/shared-1/completion');
    expect(local.outbox.single['kind'], 'patch');
  });

  test(
    'an offline room message stays in cache with a stable retry id',
    () async {
      final api = _FakeApiClient();
      final local = _FakeLocalStore();
      final controller =
          AppController(
              api: api,
              local: local,
              realtime: _FakeRealtimeService(),
            )
            ..currentUser = user
            ..activeRoomId = 'room-1';
      addTearDown(controller.dispose);

      await controller.sendRoomMessage('  I finished the reading  ');

      final cached = local.cache['messages:room-1'] as List;
      expect(cached, hasLength(1));
      expect(cached.single['body'], 'I finished the reading');
      expect(cached.single['id'], cached.single['client_mutation_id']);
      expect(local.outbox.single['kind'], 'post');
      final payload = jsonDecode(local.outbox.single['payload']! as String);
      expect(payload['clientMutationId'], cached.single['id']);
      expect(controller.roomMessages.single.body, 'I finished the reading');
    },
  );

  test('an offline direct message stays cached with its retry id', () async {
    final api = _FakeApiClient();
    final local = _FakeLocalStore();
    final controller = AppController(
      api: api,
      local: local,
      realtime: _FakeRealtimeService(),
    )..currentUser = user;
    addTearDown(controller.dispose);

    await controller.sendDirectMessage('request-1', 'Can we study tomorrow?');

    final cached = local.cache['direct_messages:request-1'] as List;
    expect(cached, hasLength(1));
    expect(cached.single['body'], 'Can we study tomorrow?');
    expect(cached.single['sender_id'], user.id);
    expect(local.outbox.single['path'], '/direct/request-1/messages');
    final payload = jsonDecode(local.outbox.single['payload']! as String);
    expect(payload['clientMutationId'], cached.single['id']);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient();
  Future<Map<String, dynamic>> Function(String path, Map<String, dynamic> body)?
  patchBehavior;
  Future<Map<String, dynamic>> Function(String path)? getBehavior;
  Future<Map<String, dynamic>> Function(String path, Map<String, dynamic> body)?
  postBehavior;
  String? lastPostedPath;
  Map<String, dynamic> lastPostedBody = const {};
  Map<String, String>? lastQuery;

  @override
  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final behavior = patchBehavior;
    if (behavior != null) return behavior(path, body);
    throw const SocketException('offline');
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic> body = const {},
    bool authenticated = true,
  ]) async {
    lastPostedPath = path;
    lastPostedBody = body;
    final behavior = postBehavior;
    if (behavior != null) return behavior(path, body);
    throw const SocketException('offline');
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    lastQuery = query;
    final behavior = getBehavior;
    if (behavior != null) return behavior(path);
    throw const SocketException('offline');
  }
}

class _FakeReminderScheduler implements OccurrenceReminderScheduler {
  bool permissionGranted = true;
  List<Map<String, dynamic>>? lastSynced;
  bool cancelledAll = false;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> syncCalendar(List<Map<String, dynamic>> occurrences) async {
    lastSynced = occurrences;
  }

  @override
  Future<void> cancelAllOccurrenceReminders() async {
    cancelledAll = true;
  }
}

class _FakeLocalStore implements LocalStore {
  final cache = <String, dynamic>{};
  final outbox = <Map<String, Object?>>[];

  @override
  Future<void> cacheJson(String key, Object value) async => cache[key] = value;

  @override
  Future<void> clearUserCache() async {
    cache.clear();
    outbox.clear();
  }

  @override
  Future<void> close() async {}

  @override
  Future<List<Map<String, Object?>>> pending() async => List.of(outbox);

  @override
  Future<dynamic> readJson(String key) async => cache[key];

  @override
  Future<void> removeCache(String key) async => cache.remove(key);

  @override
  Future<void> queue(
    String id,
    String kind,
    String path,
    Map<String, dynamic> payload,
  ) async {
    if (outbox.any((item) => item['id'] == id)) return;
    outbox.add({
      'id': id,
      'kind': kind,
      'path': path,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> removePending(String id) async {
    outbox.removeWhere((item) => item['id'] == id);
  }
}

class _FakeRealtimeService extends RealtimeService {
  final presenceUpdates = <(String, String)>[];
  @override
  void connect(
    String baseUrl,
    String token,
    void Function(String event, dynamic payload) onEvent,
  ) {}

  @override
  void disconnect() {}

  @override
  void subscribe(String roomId) {}

  @override
  void unsubscribe(String roomId) {}

  @override
  void updatePresence(String roomId, String status) =>
      presenceUpdates.add((roomId, status));
}
