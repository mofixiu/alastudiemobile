import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/models/app_models.dart';
import '../../core/network/api_client.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/storage/local_store.dart';
import '../../core/theme/native_appearance.dart';
import '../calendar/local_reminder_service.dart';
import '../nearby/nearby_session_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required ApiClient api,
    required LocalStore local,
    required RealtimeService realtime,
    OccurrenceReminderScheduler? reminders,
  }) : _api = api,
       _local = local,
       _realtime = realtime,
       _reminders = reminders ?? LocalReminderService.instance;

  final ApiClient _api;
  final LocalStore _local;
  final RealtimeService _realtime;
  final OccurrenceReminderScheduler _reminders;
  AppUser? currentUser;
  List<StudyRoom> discoveryRooms = [];
  List<JsonMap> plannerBlocks = [];
  int plannerGoal = 3;
  int plannerCompletedThisWeek = 0;
  JsonMap matchingPreferences = {
    'enabled': false,
    'subjects': [],
    'courses': [],
    'availability': [],
  };
  List<JsonMap> recommendedRooms = [];
  List<JsonMap> recommendedPeople = [];
  List<JsonMap> friends = [];
  List<JsonMap> friendRequests = [];
  List<JsonMap> achievements = [];
  List<JsonMap> weeklyLeaderboard = [];
  JsonMap leaderboardSettings = {'enabled': false, 'display_name': ''};
  List<JsonMap> communities = [];
  JsonMap aiStatus = {'enabled': false};
  List<JsonMap> personalStudyDocuments = [];
  String? _personalStudyDocumentsOwnerId;
  final Map<String, List<JsonMap>> roomMaterials = {};
  final Map<String, List<JsonMap>> roomNotes = {};
  final Map<String, JsonMap> roomWhiteboards = {};
  List<StudyRoom> myRooms = [];
  List<JsonMap> calendarOccurrences = [];
  List<JsonMap> roomTemplates = [];
  List<StudyTask> personalTasks = [];
  List<JsonMap> notifications = [];
  List<JsonMap> directRequests = [];
  List<JsonMap> conversations = [];
  List<JsonMap> roomInvitations = [];
  JsonMap stats = {};
  String? activeRoomId;
  JsonMap activeRoom = {};
  List<StudyTask> roomTasks = [];
  List<StudyMessage> roomMessages = [];
  List<JsonMap> roomMembers = [];
  Map<String, String> roomPresence = {};
  final Map<String, List<StudyMessage>> directMessages = {};
  StudySession? activeSession;
  List<JsonMap> localEmails = [];
  bool busy = false;
  bool booting = true;
  bool previewMode = false;
  bool darkModeEnabled = false;
  bool discoveryUnavailable = false;
  bool loadingDiscovery = false;
  bool loadingCalendar = false;
  DateTime? _calendarFrom;
  DateTime? _calendarTo;
  bool loadingTemplates = false;
  bool loadingHistory = false;
  bool loadingStats = false;
  bool loadingMine = false;
  bool loadingPersonalTasks = false;
  String? errorMessage;
  String? statusMessage;
  int selectedTab = 0;
  int sessionSeconds = 0;
  Timer? _sessionTicker;
  bool _refreshingSession = false;
  int _discoveryRequestVersion = 0;

  bool get signedIn => currentUser != null;
  String roomShareLink(String roomId) =>
      '${_api.shareBaseUrl}/share/rooms/${Uri.encodeComponent(roomId)}';
  bool get isHost =>
      activeRoom['role'] == 'host' || activeRoom['host_id'] == currentUser?.id;
  bool _hasRoomPermission(String permission) {
    final raw = activeRoom['permissions'];
    return raw is Map && raw[permission] == true;
  }

  bool get canManageMembers => isHost || _hasRoomPermission('manage_members');
  bool get canEditRoom => isHost || _hasRoomPermission('manage_room');
  bool get canManageSchedule => isHost || _hasRoomPermission('manage_schedule');
  bool get canManageAttendance =>
      isHost || _hasRoomPermission('manage_attendance');
  bool get canModerateRoomChat => isHost || _hasRoomPermission('moderate_chat');
  bool get isRoomManager =>
      canManageMembers ||
      canEditRoom ||
      canManageSchedule ||
      canManageAttendance ||
      canModerateRoomChat;
  String get displayName =>
      (currentUser?.profile['displayName'] as String?)?.trim().isNotEmpty ==
          true
      ? currentUser!.profile['displayName'] as String
      : currentUser?.username ?? 'student';

  static const demoUser = AppUser(
    id: 'preview-user',
    email: 'hello@alastudie.local',
    username: 'Mofiyin',
    profile: {'displayName': 'Mofiyin'},
  );
  static const demoRooms = [
    StudyRoom(
      id: 'preview-1',
      title: 'Make it through CSC 401',
      subject: 'Computer science',
      course: 'CSC 401 · Operating systems',
      goal: 'Finish process scheduling notes',
      hostName: 'Nia',
      memberCount: 6,
      participantLimit: 8,
      isMember: true,
      role: 'member',
    ),
    StudyRoom(
      id: 'preview-2',
      title: 'Quiet chemistry hour',
      subject: 'Chemistry',
      course: 'CHM 211 · Organic chemistry',
      goal: 'Review reaction mechanisms',
      hostName: 'Tobi',
      memberCount: 4,
      participantLimit: 10,
    ),
    StudyRoom(
      id: 'preview-3',
      title: 'Linear algebra, no panic',
      subject: 'Mathematics',
      course: 'MTH 202',
      goal: 'Solve 8 practice problems',
      hostName: 'Zara',
      memberCount: 3,
      participantLimit: 6,
    ),
  ];

  Future<void> restore() async {
    booting = true;
    notifyListeners();
    darkModeEnabled = await _local.readJson('appearance:dark_mode') == true;
    final token = await _api.token;
    if (token != null) {
      try {
        final response = await _api.get('/me');
        currentUser = AppUser.fromJson(response['user'] as JsonMap);
        _connect(token);
        unawaited(refreshHome());
      } catch (_) {
        await _restoreCachedHome();
        discoveryUnavailable = discoveryRooms.isEmpty;
        errorMessage =
            'Local API is offline. Cached study data is still available.';
      }
    }
    booting = false;
    notifyListeners();
  }

  Future<void> setDarkModeEnabled(bool enabled) async {
    darkModeEnabled = enabled;
    await _local.cacheJson('appearance:dark_mode', enabled);
    unawaited(NativeAppearance.setDarkMode(enabled));
    notifyListeners();
  }

  void _connect(String token) {
    final base = _api.baseUrl;
    _realtime.connect(base, token, (event, payload) {
      if (event == 'presence:snapshot' && payload is Map) {
        roomPresence =
            (payload['members'] as Map?)?.map(
              (key, value) => MapEntry('$key', '$value'),
            ) ??
            {};
      } else if (event == 'session:update' &&
          payload is Map &&
          payload['id'] != null) {
        activeSession = StudySession.fromJson(payload.cast<String, dynamic>());
        sessionSeconds = activeSession!.remainingSeconds;
      } else if (event == 'whiteboard:update' && payload is Map) {
        final roomId = '${payload['roomId'] ?? ''}';
        final board = payload['whiteboard'];
        if (roomId.isNotEmpty && board is Map) {
          roomWhiteboards[roomId] = board.cast<String, dynamic>();
          notifyListeners();
        }
      } else if (event == 'room:removed' &&
          payload is Map &&
          payload['roomId'] == activeRoomId) {
        _realtime.unsubscribe(activeRoomId!);
        activeRoomId = null;
        activeRoom = {};
        statusMessage = 'The room host removed you from the room.';
        unawaited(loadMine());
      } else if (event == 'room:closed' &&
          payload is Map &&
          payload['roomId'] == activeRoomId) {
        _realtime.unsubscribe(activeRoomId!);
        activeRoomId = null;
        activeRoom = {};
        statusMessage = 'The host closed this room.';
        unawaited(loadMine());
      } else if (event == 'socket:connect') {
        unawaited(syncOutbox());
      } else if (event == 'notification:new' && payload is Map) {
        notifications = [payload.cast<String, dynamic>(), ...notifications];
      } else if (event == 'direct:message' && payload is Map) {
        final message = payload.cast<String, dynamic>();
        final conversationId = '${message['request_id'] ?? ''}';
        if (conversationId.isNotEmpty) {
          final current =
              directMessages[conversationId] ?? const <StudyMessage>[];
          if (!current.any((item) => item.id == '${message['id']}')) {
            directMessages[conversationId] = [
              ...current,
              StudyMessage.fromJson(message, currentUser?.id ?? ''),
            ];
            unawaited(_cacheDirectMessages(conversationId));
          }
        }
      } else if (event == 'direct:message_changed' && payload is Map) {
        final message = payload.cast<String, dynamic>();
        final conversationId = '${message['request_id'] ?? ''}';
        final current = directMessages[conversationId];
        if (conversationId.isNotEmpty && current != null) {
          directMessages[conversationId] = current
              .map(
                (item) => item.id == '${message['id']}'
                    ? StudyMessage(
                        id: item.id,
                        body: item.body,
                        senderName: item.senderName,
                        isMine: item.isMine,
                        isPinned: message['is_pinned'] == true,
                        reactions: item.reactions,
                        replyBody: item.replyBody,
                        createdAt: item.createdAt,
                      )
                    : item,
              )
              .toList();
          unawaited(_cacheDirectMessages(conversationId));
        }
      } else if (event.startsWith('task:') ||
          event == 'room:message' ||
          event == 'room:message_changed' ||
          event == 'room:member_joined' ||
          event == 'room:role_changed') {
        final eventRoom = payload is Map
            ? payload['roomId'] ?? payload['room_id']
            : null;
        if (activeRoomId != null &&
            (event.startsWith('task:') || eventRoom == activeRoomId)) {
          unawaited(loadRoom(activeRoomId!));
        }
      }
      notifyListeners();
    });
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required bool ageConfirmed,
  }) async {
    await _withBusy(() async {
      await _api.post('/auth/register', {
        'email': email,
        'username': username,
        'password': password,
        'ageConfirmed': ageConfirmed,
      }, false);
      statusMessage =
          'Account created. Check the local mailbox for your verification code.';
    });
  }

  Future<void> verifyEmail(String email, String code) async {
    await _withBusy(() async {
      final response = await _api.post('/auth/verify', {
        'email': email,
        'code': code,
      }, false);
      statusMessage = response['message'] as String? ?? 'Email verified.';
    });
  }

  Future<void> login(String identifier, String password) async {
    await _withBusy(() async {
      final result = await _api.post('/auth/login', {
        'identifier': identifier.trim(),
        'password': password,
      }, false);
      final token = '${result['token']}';
      await _api.saveToken(token);
      currentUser = AppUser.fromJson(result['user'] as JsonMap);
      await _local.cacheJson('user', result['user']!);
      previewMode = false;
      errorMessage = null;
      _connect(token);
      unawaited(refreshHome());
    });
  }

  Future<void> forgotPassword(String email) async {
    await _withBusy(() async {
      final response = await _api.post('/auth/forgot-password', {
        'email': email,
      }, false);
      statusMessage =
          response['message'] as String? ?? 'Check the local mailbox.';
    });
  }

  Future<void> resetPassword(String email, String code, String password) async {
    await _withBusy(() async {
      final response = await _api.post('/auth/reset-password', {
        'email': email,
        'code': code,
        'password': password,
      }, false);
      statusMessage = response['message'] as String? ?? 'Password reset.';
    });
  }

  Future<void> loadLocalMailbox(String email) async {
    try {
      final result = await _api.get(
        '/dev/mailbox',
        query: {'email': email},
        authenticated: false,
      );
      localEmails = (result['messages'] as List? ?? [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      errorMessage = null;
    } catch (error) {
      errorMessage = '$error';
    }
    notifyListeners();
  }

  Future<void> logout() async {
    final nearby = NearbySessionService.instance;
    if (nearby.isHost || nearby.isConnected || nearby.isHosting) {
      await recordNearbySummary(nearby.summary());
      await nearby.closeSession();
    }
    if (!previewMode) {
      try {
        await _api.post('/auth/logout');
      } catch (_) {}
    }
    _realtime.disconnect();
    await _reminders.cancelAllOccurrenceReminders();
    await _api.clearToken();
    await _local.clearUserCache();
    currentUser = null;
    personalStudyDocuments = [];
    _personalStudyDocumentsOwnerId = null;
    previewMode = false;
    activeRoomId = null;
    activeRoom = {};
    discoveryRooms = [];
    discoveryUnavailable = false;
    myRooms = [];
    personalTasks = [];
    notifications = [];
    conversations = [];
    directRequests = [];
    roomInvitations = [];
    roomTasks = [];
    roomMessages = [];
    roomMembers = [];
    roomPresence = {};
    directMessages.clear();
    stats = {};
    _sessionTicker?.cancel();
    errorMessage = null;
    statusMessage = null;
    notifyListeners();
  }

  void enterPreview() {
    previewMode = true;
    currentUser = demoUser;
    personalStudyDocuments = [];
    _personalStudyDocumentsOwnerId = demoUser.id;
    discoveryUnavailable = false;
    errorMessage = null;
    discoveryRooms = demoRooms;
    myRooms = [demoRooms.first];
    personalTasks = const [
      StudyTask(
        id: 'p1',
        title: 'Read lecture 3',
        completed: true,
        personal: true,
      ),
      StudyTask(id: 'p2', title: 'Make 12 flashcards', personal: true),
    ];
    stats = {
      'streakDays': 4,
      'focusedSeconds30Days': 11 * 3600 + 28 * 60,
      'days': const [],
    };
    notifications = const [
      {
        'title': 'Your next room is warming up',
        'body': 'CSC 401 begins in 15 minutes.',
        'kind': 'session_start',
        'is_read': false,
      },
      {
        'title': 'A study invitation',
        'body': 'Zara invited you to Linear algebra, no panic.',
        'kind': 'room_invite',
        'is_read': true,
      },
    ];
    statusMessage = 'Preview mode · changes stay on this device.';
    notifyListeners();
  }

  Future<void> refreshHome() async {
    if (previewMode) {
      await loadDiscovery();
      return;
    }
    if (currentUser == null) return;
    await Future.wait([
      loadDiscovery(),
      loadMine(),
      loadPersonalTasks(),
      loadNotifications(),
      loadStats(),
      loadDirectData(),
      loadRoomInvitations(),
    ]);
    await syncOutbox();
  }

  Future<void> loadDiscovery({
    String query = '',
    String subject = '',
    String course = '',
    DateTime? startAfter,
    DateTime? startBefore,
    int availableSeats = 0,
  }) async {
    final requestVersion = ++_discoveryRequestVersion;
    loadingDiscovery = true;
    notifyListeners();
    try {
      if (previewMode) {
        discoveryUnavailable = false;
        discoveryRooms = demoRooms.where((room) {
          final matchesText =
              query.isEmpty ||
              '${room.title} ${room.subject} ${room.course} ${room.goal}'
                  .toLowerCase()
                  .contains(query.toLowerCase());
          final matchesSubject =
              subject.isEmpty ||
              room.subject.toLowerCase().contains(subject.toLowerCase());
          final matchesCourse =
              course.isEmpty ||
              room.course.toLowerCase().contains(course.toLowerCase());
          return matchesText && matchesSubject && matchesCourse;
        }).toList();
        return;
      }
      final queryParams = <String, String>{'q': query};
      if (subject.trim().isNotEmpty) queryParams['subject'] = subject.trim();
      if (course.trim().isNotEmpty) queryParams['course'] = course.trim();
      if (startAfter != null)
        queryParams['startAfter'] = startAfter.toUtc().toIso8601String();
      if (startBefore != null)
        queryParams['startBefore'] = startBefore.toUtc().toIso8601String();
      if (availableSeats > 0) queryParams['availableSeats'] = '$availableSeats';
      final response = await _api.get('/rooms', query: queryParams);
      if (requestVersion != _discoveryRequestVersion) return;
      discoveryRooms = (response['rooms'] as List? ?? [])
          .whereType<Map>()
          .map((x) => StudyRoom.fromJson(x.cast<String, dynamic>()))
          .toList();
      discoveryUnavailable = false;
      await _local.cacheJson('discovery', (response['rooms'] as List? ?? []));
      errorMessage = null;
    } catch (error) {
      if (requestVersion != _discoveryRequestVersion) return;
      final cached = await _local.readJson('discovery');
      if (cached is List)
        discoveryRooms = cached
            .whereType<Map>()
            .map((x) => StudyRoom.fromJson(x.cast<String, dynamic>()))
            .toList();
      discoveryUnavailable = discoveryRooms.isEmpty;
      if (discoveryRooms.isEmpty) errorMessage = '$error';
    } finally {
      if (requestVersion == _discoveryRequestVersion) {
        loadingDiscovery = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMine() async {
    if (previewMode) return;
    loadingMine = true;
    notifyListeners();
    try {
      final result = await _api.get('/rooms/mine');
      myRooms = (result['rooms'] as List? ?? [])
          .whereType<Map>()
          .map((x) => StudyRoom.fromJson(x.cast<String, dynamic>()))
          .toList();
      await _local.cacheJson('mine', result['rooms'] ?? []);
    } catch (_) {
      final cached = await _local.readJson('mine');
      if (cached is List)
        myRooms = cached
            .whereType<Map>()
            .map((x) => StudyRoom.fromJson(x.cast<String, dynamic>()))
            .toList();
    } finally {
      loadingMine = false;
      notifyListeners();
    }
  }

  Future<void> loadCalendar({DateTime? from, DateTime? to}) async {
    if (from != null || to != null) {
      _calendarFrom = from;
      _calendarTo = to;
    }
    loadingCalendar = true;
    notifyListeners();
    try {
      if (previewMode) {
        calendarOccurrences = const [];
      } else {
        final query = <String, String>{};
        if (_calendarFrom != null) {
          query['from'] = _calendarFrom!.toUtc().toIso8601String();
        }
        if (_calendarTo != null) {
          query['to'] = _calendarTo!.toUtc().toIso8601String();
        }
        final result = await _api.get(
          '/calendar',
          query: query.isEmpty ? null : query,
        );
        calendarOccurrences = (result['occurrences'] as List? ?? [])
            .whereType<Map>()
            .map((row) => row.cast<String, dynamic>())
            .toList();
        await _local.cacheJson('calendar', calendarOccurrences);
        await _syncOccurrenceReminders();
        errorMessage = null;
      }
    } catch (error) {
      final cached = await _local.readJson('calendar');
      if (cached is List) {
        calendarOccurrences = cached
            .whereType<Map>()
            .map((row) => row.cast<String, dynamic>())
            .toList();
      }
      await _syncOccurrenceReminders();
      if (calendarOccurrences.isEmpty) errorMessage = '$error';
    } finally {
      loadingCalendar = false;
      notifyListeners();
    }
  }

  Future<void> _syncOccurrenceReminders() async {
    try {
      await _reminders.syncCalendar(calendarOccurrences);
    } catch (_) {
      // Keep calendar use available if local notifications are unavailable.
    }
  }

  Future<void> rsvpOccurrence(
    String occurrenceId, {
    required String status,
    bool reminderEnabled = true,
  }) async {
    if (previewMode) return;
    var localReminderAllowed = true;
    if (status == 'going' && reminderEnabled) {
      try {
        localReminderAllowed = await _reminders.requestPermission();
      } catch (_) {
        localReminderAllowed = false;
      }
    }
    statusMessage = null;
    await _withBusy(() async {
      await _api.post('/calendar/occurrences/$occurrenceId/rsvp', {
        'status': status,
        'reminderEnabled': reminderEnabled && localReminderAllowed,
      });
      statusMessage =
          status == 'going' && reminderEnabled && !localReminderAllowed
          ? 'You’re going. Enable notifications in device settings to get an alert.'
          : status == 'going'
          ? 'RSVP saved. Your reminder is set on this device.'
          : 'RSVP updated.';
      await loadCalendar();
    });
  }

  Future<void> cancelOccurrence(String occurrenceId) async {
    if (previewMode) return;
    await _withBusy(() async {
      await _api.post('/calendar/occurrences/$occurrenceId/cancel');
      await loadCalendar();
      await loadNotifications();
    });
  }

  Future<void> rescheduleOccurrence(
    String occurrenceId,
    DateTime startsAt,
  ) async {
    if (previewMode) return;
    await _withBusy(() async {
      await _api.patch('/calendar/occurrences/$occurrenceId', {
        'startsAt': startsAt.toUtc().toIso8601String(),
      });
      statusMessage =
          'This meeting was moved. RSVPs stay with this occurrence.';
      await loadCalendar();
      await loadNotifications();
    });
  }

  Future<void> checkInOccurrence(String occurrenceId, {String? userId}) async {
    if (previewMode) return;
    await _withBusy(() async {
      await _api.post('/calendar/occurrences/$occurrenceId/attendance', {
        if (userId != null) 'userId': userId,
      });
      await loadCalendar();
    });
  }

  Future<void> loadRoomTemplates() async {
    loadingTemplates = true;
    notifyListeners();
    try {
      if (previewMode) {
        roomTemplates = const [];
      } else {
        final result = await _api.get('/room-templates');
        roomTemplates = (result['templates'] as List? ?? [])
            .whereType<Map>()
            .map((row) => row.cast<String, dynamic>())
            .toList();
        await _local.cacheJson('room_templates', roomTemplates);
      }
    } catch (_) {
      final cached = await _local.readJson('room_templates');
      if (cached is List) {
        roomTemplates = cached
            .whereType<Map>()
            .map((row) => row.cast<String, dynamic>())
            .toList();
      }
    } finally {
      loadingTemplates = false;
      notifyListeners();
    }
  }

  Future<void> saveRoomTemplate({
    required String title,
    required String subject,
    required String course,
    required String goal,
    required String accessType,
    required int participantLimit,
    required String recurrence,
  }) async {
    if (previewMode) return;
    await _withBusy(() async {
      await _api.post('/room-templates', {
        'title': title,
        'subject': subject,
        'course': course,
        'goal': goal,
        'accessType': accessType,
        'participantLimit': participantLimit,
        'recurrence': recurrence,
      });
      await loadRoomTemplates();
      statusMessage = 'Room template saved for next time.';
    });
  }

  Future<void> loadPersonalTasks() async {
    if (previewMode) return;
    loadingPersonalTasks = true;
    notifyListeners();
    try {
      final result = await _api.get('/tasks/personal');
      personalTasks = (result['tasks'] as List? ?? [])
          .whereType<Map>()
          .map(
            (x) => StudyTask.fromJson(
              x.cast<String, dynamic>(),
              userId: currentUser?.id,
            ),
          )
          .toList();
      await _local.cacheJson('personal_tasks', result['tasks'] ?? []);
    } catch (_) {
      final cached = await _local.readJson('personal_tasks');
      if (cached is List)
        personalTasks = cached
            .whereType<Map>()
            .map(
              (x) => StudyTask.fromJson(
                x.cast<String, dynamic>(),
                userId: currentUser?.id,
              ),
            )
            .toList();
    } finally {
      loadingPersonalTasks = false;
      notifyListeners();
    }
  }

  Future<void> loadNotifications() async {
    if (previewMode) return;
    try {
      final result = await _api.get('/notifications');
      notifications = (result['notifications'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
      await _local.cacheJson('notifications', notifications);
    } catch (_) {
      final cached = await _local.readJson('notifications');
      if (cached is List)
        notifications = cached
            .whereType<Map>()
            .map((x) => x.cast<String, dynamic>())
            .toList();
    }
    notifyListeners();
  }

  Future<void> loadStats() async {
    if (previewMode) return;
    loadingStats = true;
    notifyListeners();
    try {
      stats = await _api.get('/stats', query: {'timezone': _ianaTimezone()});
      await _local.cacheJson('stats', stats);
    } catch (_) {
      final cached = await _local.readJson('stats');
      if (cached is Map) stats = cached.cast<String, dynamic>();
    } finally {
      loadingStats = false;
      notifyListeners();
    }
  }

  Future<void> loadDirectData() async {
    if (previewMode) return;
    try {
      final response = await _api.get('/direct/requests');
      directRequests = (response['requests'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
      final conversationsResult = await _api.get('/direct/conversations');
      conversations = (conversationsResult['conversations'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> loadRoomInvitations() async {
    if (previewMode) return;
    try {
      final response = await _api.get('/rooms/invitations');
      roomInvitations = (response['invitations'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
      await _local.cacheJson('room_invitations', roomInvitations);
    } catch (_) {
      final cached = await _local.readJson('room_invitations');
      if (cached is List) {
        roomInvitations = cached
            .whereType<Map>()
            .map((x) => x.cast<String, dynamic>())
            .toList();
      }
    }
    notifyListeners();
  }

  Future<void> joinRoomByCode(String accessCode) async {
    if (previewMode) {
      statusMessage = 'Room codes need the local API connection.';
      notifyListeners();
      return;
    }
    await _withBusy(() async {
      final result = await _api.post('/rooms/join-by-code', {
        'accessCode': accessCode.trim(),
      });
      await loadMine();
      await openRoom('${result['roomId']}');
    });
  }

  Future<void> acceptRoomInvitation(String roomId) async {
    if (previewMode) return;
    await _withBusy(() async {
      await _api.post('/rooms/$roomId/join');
      roomInvitations.removeWhere((item) => item['room_id'] == roomId);
      await loadMine();
      await openRoom(roomId);
    });
  }

  Future<void> dismissRoomInvitation(String roomId) async {
    if (previewMode) return;
    await _withBusy(() async {
      await _api.delete('/rooms/invitations/$roomId');
      roomInvitations.removeWhere((item) => item['room_id'] == roomId);
    });
  }

  Future<void> _restoreCachedHome() async {
    final cachedUser = await _local.readJson('user');
    if (cachedUser is Map)
      currentUser = AppUser.fromJson(cachedUser.cast<String, dynamic>());
    final discovery = await _local.readJson('discovery');
    if (discovery is List) {
      discoveryRooms = discovery
          .whereType<Map>()
          .map((x) => StudyRoom.fromJson(x.cast<String, dynamic>()))
          .toList();
    }
    final mine = await _local.readJson('mine');
    if (mine is List) {
      myRooms = mine
          .whereType<Map>()
          .map((x) => StudyRoom.fromJson(x.cast<String, dynamic>()))
          .toList();
    }
    final tasks = await _local.readJson('personal_tasks');
    if (tasks is List) {
      personalTasks = tasks
          .whereType<Map>()
          .map(
            (x) => StudyTask.fromJson(
              x.cast<String, dynamic>(),
              userId: currentUser?.id,
            ),
          )
          .toList();
    }
    final cachedNotifications = await _local.readJson('notifications');
    if (cachedNotifications is List) {
      notifications = cachedNotifications
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
    }
    final cachedStats = await _local.readJson('stats');
    if (cachedStats is Map) stats = cachedStats.cast<String, dynamic>();
    final cachedInvitations = await _local.readJson('room_invitations');
    if (cachedInvitations is List) {
      roomInvitations = cachedInvitations
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
    }
  }

  Future<void> createRoom({
    required String title,
    required String subject,
    required String course,
    required String goal,
    required String accessType,
    required int limit,
    DateTime? scheduledAt,
    String recurrence = 'none',
  }) async {
    if (previewMode) {
      statusMessage =
          'Room creation is available after connecting the local API.';
      notifyListeners();
      return;
    }
    await _withBusy(() async {
      final result = await _api.post('/rooms', {
        'title': title,
        'subject': subject,
        'course': course,
        'goal': goal,
        'accessType': accessType,
        'participantLimit': limit,
        'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
        'recurrence': recurrence,
      });
      if (result['accessCode'] != null)
        statusMessage = 'Room created. Invite code: ${result['accessCode']}';
      await loadMine();
      await openRoom('${(result['room'] as Map)['id']}');
    });
  }

  Future<void> joinRoom(StudyRoom room, {String accessCode = ''}) async {
    if (previewMode) {
      statusMessage = 'Connect the local API to join a room.';
      notifyListeners();
      return;
    }
    await _withBusy(() async {
      await _api.post('/rooms/${room.id}/join', {'accessCode': accessCode});
      await loadMine();
      await openRoom(room.id);
    });
  }

  Future<void> openRoom(String roomId) async {
    activeRoomId = roomId;
    if (previewMode) {
      final room = demoRooms.firstWhere(
        (e) => e.id == roomId,
        orElse: () => demoRooms.first,
      );
      activeRoom = {
        'title': room.title,
        'subject': room.subject,
        'goal': room.goal,
        'role': room.role,
        'member_count': room.memberCount,
        'participant_limit': room.participantLimit,
      };
      roomMembers = const [
        {'id': 'preview-user', 'username': 'Mofiyin', 'role': 'member'},
        {'id': 'nia', 'username': 'Nia', 'role': 'host'},
        {'id': 'tobi', 'username': 'Tobi', 'role': 'member'},
        {'id': 'zara', 'username': 'Zara', 'role': 'member'},
      ];
      roomPresence = {
        'preview-user': 'studying',
        'nia': 'studying',
        'tobi': 'break',
        'zara': 'away',
      };
      roomTasks = const [
        StudyTask(
          id: 'rt1',
          title: 'Read the lecture notes',
          completed: true,
          completedCount: 4,
          memberCount: 6,
        ),
        StudyTask(
          id: 'rt2',
          title: 'Review process scheduling',
          completed: false,
          completedCount: 2,
          memberCount: 6,
        ),
        StudyTask(
          id: 'rt3',
          title: 'Solve practice questions',
          completed: false,
          completedCount: 1,
          memberCount: 6,
        ),
      ];
      roomMessages = const [
        StudyMessage(
          id: 'm1',
          body: 'I added the practice questions to the list.',
          senderName: 'Nia',
        ),
        StudyMessage(
          id: 'm2',
          body: 'Nice. I’m starting with scheduling.',
          senderName: 'Mofiyin',
          isMine: true,
        ),
      ];
      activeSession = const StudySession(
        id: 'preview-session',
        phase: 'focus',
        status: 'running',
        remainingSeconds: 17 * 60 + 42,
        hostId: 'nia',
      );
      sessionSeconds = activeSession!.remainingSeconds;
      _startTicker();
      notifyListeners();
      return;
    }
    try {
      final response = await _api.get('/rooms/$roomId');
      activeRoom = (response['room'] as Map).cast<String, dynamic>();
      activeRoom['role'] =
          response['role'] ??
          (activeRoom['host_id'] == currentUser?.id ? 'host' : 'member');
      activeRoom['permissions'] =
          (response['permissions'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      roomMembers = (response['members'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
      roomTasks = (response['tasks'] as List? ?? [])
          .whereType<Map>()
          .map(
            (x) => StudyTask.fromJson(
              x.cast<String, dynamic>(),
              userId: currentUser?.id,
            ),
          )
          .toList();
      roomPresence = (response['presence'] as Map? ?? {}).map(
        (key, value) => MapEntry('$key', '$value'),
      );
      activeSession = response['session'] is Map
          ? StudySession.fromJson(
              (response['session'] as Map).cast<String, dynamic>(),
            )
          : null;
      sessionSeconds = activeSession?.remainingSeconds ?? 0;
      await _local.cacheJson('room:$roomId', response);
      _realtime.subscribe(roomId);
      await loadRoomMessages(roomId);
      errorMessage = null;
      _startTicker();
    } catch (error) {
      final cache = await _local.readJson('room:$roomId');
      if (cache is Map) {
        activeRoom = (cache['room'] as Map).cast<String, dynamic>();
        roomTasks = (cache['tasks'] as List? ?? [])
            .whereType<Map>()
            .map(
              (x) => StudyTask.fromJson(
                x.cast<String, dynamic>(),
                userId: currentUser?.id,
              ),
            )
            .toList();
        roomMembers = (cache['members'] as List? ?? [])
            .whereType<Map>()
            .map((x) => x.cast<String, dynamic>())
            .toList();
        roomPresence = (cache['presence'] as Map? ?? {}).map(
          (key, value) => MapEntry('$key', '$value'),
        );
        activeSession = cache['session'] is Map
            ? StudySession.fromJson(
                (cache['session'] as Map).cast<String, dynamic>(),
              )
            : null;
        sessionSeconds = activeSession?.remainingSeconds ?? 0;
        final cachedMessages = await _local.readJson('messages:$roomId');
        if (cachedMessages is List) {
          roomMessages = cachedMessages
              .whereType<Map>()
              .map(
                (x) => StudyMessage.fromJson(
                  x.cast<String, dynamic>(),
                  currentUser?.id ?? '',
                ),
              )
              .toList();
        }
      }
      errorMessage = '$error';
    }
    notifyListeners();
  }

  Future<void> loadRoom(String roomId) async {
    if (previewMode) return;
    final response = await _api.get('/rooms/$roomId');
    if (activeRoomId != roomId) return;
    activeRoom = (response['room'] as Map).cast<String, dynamic>();
    activeRoom['role'] =
        response['role'] ??
        (activeRoom['host_id'] == currentUser?.id ? 'host' : 'member');
    activeRoom['permissions'] =
        (response['permissions'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    roomMembers = (response['members'] as List? ?? [])
        .whereType<Map>()
        .map((x) => x.cast<String, dynamic>())
        .toList();
    roomTasks = (response['tasks'] as List? ?? [])
        .whereType<Map>()
        .map(
          (x) => StudyTask.fromJson(
            x.cast<String, dynamic>(),
            userId: currentUser?.id,
          ),
        )
        .toList();
    roomPresence = (response['presence'] as Map? ?? {}).map(
      (key, value) => MapEntry('$key', '$value'),
    );
    activeSession = response['session'] is Map
        ? StudySession.fromJson(
            (response['session'] as Map).cast<String, dynamic>(),
          )
        : null;
    sessionSeconds = activeSession?.remainingSeconds ?? 0;
    await _local.cacheJson('room:$roomId', response);
    notifyListeners();
  }

  Future<void> loadRoomMessages(String roomId) async {
    if (previewMode) return;
    try {
      final result = await _api.get('/rooms/$roomId/messages');
      roomMessages = (result['messages'] as List? ?? [])
          .whereType<Map>()
          .map(
            (x) => StudyMessage.fromJson(
              x.cast<String, dynamic>(),
              currentUser?.id ?? '',
            ),
          )
          .toList();
      await _local.cacheJson('messages:$roomId', result['messages'] ?? []);
    } catch (_) {
      final cached = await _local.readJson('messages:$roomId');
      if (cached is List)
        roomMessages = cached
            .whereType<Map>()
            .map(
              (x) => StudyMessage.fromJson(
                x.cast<String, dynamic>(),
                currentUser?.id ?? '',
              ),
            )
            .toList();
    }
    notifyListeners();
  }

  Future<void> createRoomTask(String title) async {
    if (previewMode || activeRoomId == null) return;
    try {
      await _api.post('/rooms/$activeRoomId/tasks', {'title': title});
      await openRoom(activeRoomId!);
    } catch (error) {
      errorMessage = '$error';
      notifyListeners();
    }
  }

  Future<void> toggleRoomTask(StudyTask task) async {
    final value = !task.completed;
    roomTasks = roomTasks
        .map(
          (t) => t.id == task.id
              ? StudyTask(
                  id: t.id,
                  title: t.title,
                  completed: value,
                  completedCount: max(0, t.completedCount + (value ? 1 : -1)),
                  memberCount: t.memberCount,
                  personal: t.personal,
                )
              : t,
        )
        .toList();
    notifyListeners();
    if (previewMode) return;
    await _cacheRoomTaskCompletion(task.id, value);
    final path = '/tasks/${task.id}/completion';
    final payload = {'completed': value};
    try {
      await _api.patch(path, payload);
    } catch (error) {
      if (error is ApiException && error.statusCode != null) {
        errorMessage = '$error';
        await openRoom(activeRoomId!);
      } else {
        final mutation = _randomId();
        await _local.queue(mutation, 'patch', path, payload);
        statusMessage =
            'Saved on this device. It will sync when the API is back.';
      }
      notifyListeners();
    }
  }

  Future<void> sendRoomMessage(String body, {String? replyTo}) async {
    if (activeRoomId == null || body.trim().isEmpty) return;
    if (previewMode) {
      roomMessages = [
        ...roomMessages,
        StudyMessage(
          id: _randomId(),
          body: body.trim(),
          senderName: currentUser?.username ?? 'Me',
          isMine: true,
        ),
      ];
      notifyListeners();
      return;
    }
    final mutationId = _randomId();
    final optimistic = StudyMessage(
      id: mutationId,
      body: body.trim(),
      senderName: currentUser?.username ?? 'Me',
      isMine: true,
    );
    roomMessages = [...roomMessages, optimistic];
    await _cacheRoomMessage(optimistic, replyTo: replyTo);
    notifyListeners();
    final path = '/rooms/$activeRoomId/messages';
    final payload = {
      'body': body.trim(),
      'replyTo': replyTo,
      'clientMutationId': mutationId,
    };
    try {
      await _api.post(path, payload);
      await loadRoomMessages(activeRoomId!);
    } catch (error) {
      if (error is ApiException && error.statusCode != null) {
        errorMessage = '$error';
        await loadRoomMessages(activeRoomId!);
      } else {
        await _local.queue(mutationId, 'post', path, payload);
        statusMessage = 'Message queued on this device.';
      }
      notifyListeners();
    }
  }

  Future<void> createPersonalTask(String title) async {
    if (previewMode) {
      personalTasks = [
        ...personalTasks,
        StudyTask(id: _randomId(), title: title, personal: true),
      ];
      notifyListeners();
      return;
    }
    await _withBusy(() async {
      await _api.post('/tasks/personal', {'title': title});
      await loadPersonalTasks();
      statusMessage = 'Added to your plan.';
    });
  }

  Future<void> togglePersonalTask(StudyTask task) async {
    final next = !task.completed;
    personalTasks = personalTasks
        .map(
          (t) => t.id == task.id
              ? StudyTask(
                  id: t.id,
                  title: t.title,
                  completed: next,
                  personal: true,
                )
              : t,
        )
        .toList();
    notifyListeners();
    if (previewMode) return;
    await _cachePersonalTasks();
    try {
      await _api.patch('/tasks/${task.id}/completion', {'completed': next});
    } on ApiException catch (error) {
      if (error.statusCode == null) {
        await _local.queue(
          _randomId(),
          'personal_task',
          '/tasks/${task.id}/completion',
          {'completed': next},
        );
        statusMessage = 'Task completion saved here and will sync when online.';
      } else {
        personalTasks = personalTasks
            .map(
              (t) => t.id == task.id
                  ? StudyTask(
                      id: t.id,
                      title: t.title,
                      completed: task.completed,
                      personal: true,
                    )
                  : t,
            )
            .toList();
        await _cachePersonalTasks();
        errorMessage = '$error';
      }
    } catch (_) {
      await _local.queue(
        _randomId(),
        'personal_task',
        '/tasks/${task.id}/completion',
        {'completed': next},
      );
      statusMessage = 'Task completion saved here and will sync when online.';
    }
    notifyListeners();
  }

  Future<void> _cachePersonalTasks() async {
    await _local.cacheJson('personal_tasks', [
      for (final task in personalTasks)
        {
          'id': task.id,
          'title': task.title,
          'is_personal': true,
          'completed_at': task.completed
              ? DateTime.now().toIso8601String()
              : null,
        },
    ]);
  }

  Future<void> _cacheRoomTaskCompletion(String taskId, bool completed) async {
    if (activeRoomId == null) return;
    final cached = await _local.readJson('room:$activeRoomId');
    if (cached is! Map) return;
    final room = cached.cast<String, dynamic>();
    final rawTasks = (room['tasks'] as List? ?? []).whereType<Map>().map((row) {
      final task = row.cast<String, dynamic>();
      if ('${task['id']}' != taskId) return task;
      final completions = (task['completions'] as List? ?? [])
          .whereType<Map>()
          .map((entry) => entry.cast<String, dynamic>())
          .toList();
      final userId = currentUser?.id;
      final index = completions.indexWhere(
        (entry) => '${entry['userId'] ?? entry['user_id']}' == userId,
      );
      final current = <String, dynamic>{
        'userId': userId,
        'completedAt': completed ? DateTime.now().toIso8601String() : null,
      };
      if (index >= 0) {
        completions[index] = current;
      } else if (userId != null) {
        completions.add(current);
      }
      return {...task, 'completions': completions};
    }).toList();
    await _local.cacheJson('room:$activeRoomId', {...room, 'tasks': rawTasks});
  }

  Future<void> _cacheRoomMessage(
    StudyMessage message, {
    String? replyTo,
  }) async {
    if (activeRoomId == null) return;
    final key = 'messages:$activeRoomId';
    final cached = await _local.readJson(key);
    final rows = cached is List
        ? cached
              .whereType<Map>()
              .map((row) => row.cast<String, dynamic>())
              .toList()
        : <JsonMap>[];
    if (rows.any(
      (row) => '${row['id'] ?? row['client_mutation_id']}' == message.id,
    )) {
      return;
    }
    rows.add({
      'id': message.id,
      'client_mutation_id': message.id,
      'body': message.body,
      'sender_id': currentUser?.id,
      'sender_name': message.senderName,
      'reply_to': replyTo,
      'created_at': DateTime.now().toIso8601String(),
      'is_pinned': false,
      'reactions': <JsonMap>[],
    });
    await _local.cacheJson(key, rows);
  }

  Future<void> startSession({
    String preset = 'classic',
    int focusMinutes = 25,
    int breakMinutes = 5,
  }) async {
    if (previewMode) {
      activeSession = StudySession(
        id: 'preview-session',
        phase: 'focus',
        status: 'running',
        remainingSeconds: focusMinutes * 60,
        preset: preset,
        hostId: currentUser?.id ?? '',
      );
      sessionSeconds = focusMinutes * 60;
      _startTicker();
      notifyListeners();
      return;
    }
    if (activeRoomId == null) return;
    await _withBusy(() async {
      final response = await _api.post('/rooms/$activeRoomId/sessions', {
        'preset': preset,
        'focusMinutes': focusMinutes,
        'breakMinutes': breakMinutes,
      });
      activeSession = StudySession.fromJson(
        (response['session'] as Map).cast<String, dynamic>(),
      );
      sessionSeconds = activeSession!.remainingSeconds;
      _startTicker();
    });
  }

  Future<void> controlSession(String action) async {
    if (activeSession == null) return;
    if (previewMode) {
      activeSession = StudySession(
        id: activeSession!.id,
        phase: action == 'finish' ? 'finished' : activeSession!.phase,
        status: action == 'pause'
            ? 'paused'
            : action == 'finish'
            ? 'finished'
            : 'running',
        remainingSeconds: sessionSeconds,
        hostId: activeSession!.hostId,
      );
      notifyListeners();
      return;
    }
    await _withBusy(() async {
      final response = await _api.post(
        '/sessions/${activeSession!.id}/control',
        {'action': action},
      );
      if (response['session'] is Map)
        activeSession = StudySession.fromJson(
          (response['session'] as Map).cast<String, dynamic>(),
        );
      else
        activeSession = null;
      sessionSeconds = activeSession?.remainingSeconds ?? 0;
    });
  }

  void setPresence(String status) {
    if (!const {'studying', 'break', 'away'}.contains(status)) return;
    final roomId = activeRoomId;
    if (roomId == null) return;
    roomPresence = {...roomPresence, currentUser?.id ?? 'preview-user': status};
    if (!previewMode) _realtime.updatePresence(roomId, status);
    notifyListeners();
  }

  Future<void> updateProfile({
    required String displayName,
    required String school,
    required String subjects,
    required bool publicProfile,
    required bool allowMessageRequests,
  }) async {
    final profile = {
      'displayName': displayName,
      'school': school,
      'subjects': subjects
          .split(',')
          .map((x) => x.trim())
          .where((x) => x.isNotEmpty)
          .toList(),
      'visibility': publicProfile ? 'public' : 'private',
      'allowMessageRequests': allowMessageRequests,
    };
    if (previewMode) {
      currentUser = AppUser(
        id: currentUser!.id,
        email: currentUser!.email,
        username: currentUser!.username,
        profile: profile,
      );
      notifyListeners();
      return;
    }
    await _withBusy(() async {
      final result = await _api.patch('/me/profile', profile);
      currentUser = AppUser.fromJson(
        (result['user'] as Map).cast<String, dynamic>(),
      );
      await _local.cacheJson('user', result['user']!);
    });
  }

  Future<void> requestDirectMessage(String username) async {
    if (previewMode) {
      statusMessage =
          'Message requests are available after connecting the local API.';
      notifyListeners();
      return;
    }
    await _withBusy(() async {
      await _api.post('/direct/requests', {'username': username});
      await loadDirectData();
    });
  }

  Future<void> respondToRequest(String requestId, bool accept) async {
    if (previewMode) return;
    await _withBusy(() async {
      await _api.post('/direct/requests/$requestId/respond', {
        'accept': accept,
      });
      await loadDirectData();
    });
  }

  Future<void> loadPlanner({DateTime? from, DateTime? to}) async {
    if (currentUser == null || previewMode) return;
    final start = from ?? DateTime.now().subtract(const Duration(days: 7));
    final end = to ?? DateTime.now().add(const Duration(days: 21));
    final query = {
      'from': start.toUtc().toIso8601String(),
      'to': end.toUtc().toIso8601String(),
    };
    try {
      final result = await _api.get('/planner/blocks', query: query);
      plannerBlocks = (result['blocks'] as List? ?? [])
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
      plannerGoal = int.tryParse('${result['goal'] ?? 3}') ?? 3;
      plannerCompletedThisWeek =
          int.tryParse('${result['completedThisWeek'] ?? 0}') ?? 0;
      await _local.cacheJson('planner:${currentUser!.id}', {
        'blocks': plannerBlocks,
        'goal': plannerGoal,
        'completedThisWeek': plannerCompletedThisWeek,
      });
    } catch (_) {
      final cached = await _local.readJson('planner:${currentUser!.id}');
      if (cached is Map) {
        plannerBlocks = (cached['blocks'] as List? ?? [])
            .whereType<Map>()
            .map((x) => x.cast<String, dynamic>())
            .toList();
        plannerGoal = int.tryParse('${cached['goal'] ?? 3}') ?? 3;
        plannerCompletedThisWeek =
            int.tryParse('${cached['completedThisWeek'] ?? 0}') ?? 0;
      }
    }
    notifyListeners();
  }

  Future<void> setPlannerGoal(int sessionsPerWeek) async {
    await _roadmapAction(() async {
      await _api.put('/planner/goal', {'sessionsPerWeek': sessionsPerWeek});
      plannerGoal = sessionsPerWeek;
      await loadPlanner();
    });
  }

  Future<void> addPlannerBlock({
    required String title,
    required String subject,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool reminderEnabled,
  }) async {
    await _roadmapAction(() async {
      var scheduleReminder = reminderEnabled;
      if (scheduleReminder) {
        scheduleReminder = await LocalReminderService.instance
            .requestPermission();
        if (!scheduleReminder)
          statusMessage =
              'The block was saved, but notifications are disabled in device settings.';
      }
      final result = await _api.post('/planner/blocks', {
        'title': title,
        'subject': subject,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'reminderEnabled': scheduleReminder,
      });
      final block = (result['block'] as Map).cast<String, dynamic>();
      await loadPlanner(
        from: startsAt.subtract(const Duration(days: 7)),
        to: endsAt.add(const Duration(days: 7)),
      );
      if (scheduleReminder)
        await LocalReminderService.instance.schedulePlannerBlock(block);
    });
  }

  Future<void> updatePlannerBlock(
    String id,
    Map<String, dynamic> changes,
  ) async {
    await _roadmapAction(() async {
      final result = await _api.patch('/planner/blocks/$id', changes);
      final block = (result['block'] as Map).cast<String, dynamic>();
      await loadPlanner();
      if (block['reminder_enabled'] == true) {
        await LocalReminderService.instance.schedulePlannerBlock(block);
      } else {
        await LocalReminderService.instance.cancelPlannerBlock(id);
      }
    });
  }

  Future<void> deletePlannerBlock(String id) async {
    await _roadmapAction(() async {
      await _api.delete('/planner/blocks/$id');
      await LocalReminderService.instance.cancelPlannerBlock(id);
      plannerBlocks.removeWhere((block) => '${block['id']}' == id);
    });
  }

  Future<void> carryForwardPlannerBlocks(List<JsonMap> copies) async {
    if (copies.isEmpty) return;
    await _roadmapAction(() async {
      await _api.post('/planner/blocks/carry-forward', {'copies': copies});
      await loadPlanner();
    });
  }

  Future<void> loadMatching() async {
    if (currentUser == null || previewMode) return;
    try {
      final result = await _api.get('/matching/preferences');
      matchingPreferences = (result['preferences'] as Map)
          .cast<String, dynamic>();
      await loadRecommendations();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> saveMatchingPreferences({
    required bool enabled,
    required List<String> subjects,
    required List<String> courses,
    required List<String> availability,
  }) async {
    await _roadmapAction(() async {
      final result = await _api.put('/matching/preferences', {
        'enabled': enabled,
        'subjects': subjects,
        'courses': courses,
        'availability': availability,
      });
      matchingPreferences = (result['preferences'] as Map)
          .cast<String, dynamic>();
      await loadRecommendations();
    });
  }

  Future<void> loadRecommendations() async {
    try {
      final result = await _api.get('/recommendations');
      recommendedRooms = (result['rooms'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
      recommendedPeople = (result['people'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
    } catch (_) {
      recommendedRooms = [];
      recommendedPeople = [];
    }
    notifyListeners();
  }

  Future<void> loadFriends() async {
    if (previewMode) return;
    try {
      final results = await Future.wait([
        _api.get('/friends'),
        _api.get('/friends/requests'),
      ]);
      friends = (results[0]['friends'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
      friendRequests = (results[1]['requests'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> requestFriend(String username) async => _roadmapAction(() async {
    await _api.post('/friends/requests', {'username': username});
    await loadFriends();
  });

  Future<void> respondToFriendRequest(
    String id, {
    required bool accept,
  }) async => _roadmapAction(() async {
    await _api.patch('/friends/requests/$id', {
      'action': accept ? 'accept' : 'decline',
    });
    await loadFriends();
  });

  Future<void> removeFriend(String id) async => _roadmapAction(() async {
    await _api.delete('/friends/$id');
    friends.removeWhere((item) => '${item['id']}' == id);
  });

  Future<void> loadProgress() async {
    if (previewMode) return;
    try {
      final values = await Future.wait([
        _api.get('/achievements'),
        _api.get('/leaderboard/settings'),
        _api.get('/leaderboard/weekly'),
      ]);
      achievements = (values[0]['achievements'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
      leaderboardSettings = (values[1]['settings'] as Map)
          .cast<String, dynamic>();
      weeklyLeaderboard = (values[2]['entries'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setLeaderboard({
    required bool enabled,
    required String displayName,
  }) async => _roadmapAction(() async {
    final result = await _api.put('/leaderboard/settings', {
      'enabled': enabled,
      'displayName': displayName,
    });
    leaderboardSettings = (result['settings'] as Map).cast<String, dynamic>();
    await loadProgress();
  });

  Future<void> loadRoomResources(String roomId) async {
    try {
      final result = await Future.wait([
        _api.get('/rooms/$roomId/materials'),
        _api.get('/rooms/$roomId/notes'),
        _api.get('/rooms/$roomId/whiteboard'),
      ]);
      roomMaterials[roomId] = (result[0]['materials'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
      roomNotes[roomId] = (result[1]['notes'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
      roomWhiteboards[roomId] =
          (result[2]['whiteboard'] as Map?)?.cast<String, dynamic>() ??
          {'strokes': [], 'version': 0};
    } catch (_) {}
    notifyListeners();
  }

  Future<void> shareRoomMaterial(
    String roomId, {
    required String title,
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async => _roadmapAction(() async {
    await _api.post('/rooms/$roomId/materials', {
      'title': title,
      'fileName': fileName,
      'contentType': contentType,
      'dataBase64': base64Encode(bytes),
    });
    await loadRoomResources(roomId);
  });

  Future<List<int>> downloadRoomMaterial(String roomId, String materialId) =>
      _api.getBytes('/rooms/$roomId/materials/$materialId/download');

  Future<void> deleteRoomMaterial(String roomId, String materialId) async =>
      _roadmapAction(() async {
        await _api.delete('/rooms/$roomId/materials/$materialId');
        await loadRoomResources(roomId);
      });

  Future<void> createRoomNote(String roomId, String title, String body) async =>
      _roadmapAction(() async {
        await _api.post('/rooms/$roomId/notes', {'title': title, 'body': body});
        await loadRoomResources(roomId);
      });

  Future<void> saveRoomNote(
    String roomId,
    JsonMap note,
    String title,
    String body,
  ) async => _roadmapAction(() async {
    await _api.patch('/rooms/$roomId/notes/${note['id']}', {
      'version': note['version'],
      'title': title,
      'body': body,
    });
    await loadRoomResources(roomId);
  });

  Future<void> deleteRoomNote(String roomId, String noteId) async =>
      _roadmapAction(() async {
        await _api.delete('/rooms/$roomId/notes/$noteId');
        await loadRoomResources(roomId);
      });

  Future<void> saveRoomWhiteboard(
    String roomId,
    List<JsonMap> strokes,
    int version,
  ) async => _roadmapAction(() async {
    final result = await _api.put('/rooms/$roomId/whiteboard', {
      'strokes': strokes,
      'version': version,
    });
    roomWhiteboards[roomId] = (result['whiteboard'] as Map)
        .cast<String, dynamic>();
  });

  Future<void> loadCommunities() async {
    try {
      final result = await _api.get('/communities');
      communities = (result['communities'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> requestSchoolEmail(String email) async =>
      _roadmapAction(() async {
        await _api.post('/communities/school-email/request', {'email': email});
      });

  Future<void> verifySchoolEmail(String email, String code) async =>
      _roadmapAction(() async {
        await _api.post('/communities/school-email/verify', {
          'email': email,
          'code': code,
        });
        await loadCommunities();
      });

  Future<void> joinCommunity(String id) async => _roadmapAction(() async {
    await _api.post('/communities/$id/join');
    await loadCommunities();
  });

  Future<void> inviteCommunityMember(String id, String username) async =>
      _roadmapAction(() async {
        await _api.post('/communities/$id/invites', {'username': username});
      });

  Future<void> createInstitution(String name, String domain) async =>
      _roadmapAction(() async {
        await _api.post('/admin/institutions', {
          'name': name,
          'domain': domain,
        });
        await loadCommunities();
      });

  Future<void> loadAiStatus() async {
    try {
      aiStatus = await _api.get('/ai/status');
    } catch (_) {
      aiStatus = {'enabled': false};
    }
    notifyListeners();
  }

  Future<void> loadPersonalStudyDocuments() async {
    final ownerId = currentUser?.id;
    if (_personalStudyDocumentsOwnerId != ownerId) {
      personalStudyDocuments = [];
      _personalStudyDocumentsOwnerId = ownerId;
    }
    if (ownerId == null || previewMode) {
      notifyListeners();
      return;
    }
    try {
      final result = await _api.get('/study-documents');
      if (currentUser?.id != ownerId || previewMode) return;
      personalStudyDocuments = (result['documents'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> uploadPersonalStudyDocument({
    required String fileName,
    required List<int> bytes,
  }) async => _roadmapAction(() async {
    await _api.post('/study-documents', {
      'fileName': fileName,
      'contentType': 'application/pdf',
      'dataBase64': base64Encode(bytes),
    });
    await loadPersonalStudyDocuments();
  });

  Future<List<int>> downloadPersonalStudyDocument(String documentId) =>
      _api.getBytes('/study-documents/$documentId/download');

  Future<void> deletePersonalStudyDocument(String documentId) async =>
      _roadmapAction(() async {
        await _api.delete('/study-documents/$documentId');
        await loadPersonalStudyDocuments();
      });

  Future<JsonMap> askAi({
    required String operation,
    required String prompt,
    String? roomId,
    List<String> materialIds = const [],
    List<String> studyDocumentIds = const [],
    bool includePlan = false,
  }) async => _api.post('/ai/requests', {
    'operation': operation,
    'prompt': prompt,
    'roomId': roomId,
    'materialIds': materialIds,
    'studyDocumentIds': studyDocumentIds,
    'includePlan': includePlan,
    // The AI screen tells the user both of these before they submit.
    'confirmGoogleProcessing': true,
    'confirmPersistentIndex': materialIds.isNotEmpty || studyDocumentIds.isNotEmpty,
  });

  Future<void> removeAiIndex(String materialId) async {
    await _api.delete('/ai/material-index/$materialId');
  }

  Future<void> recordNearbySummary(JsonMap summary) async {
    final id = '${summary['clientSessionId'] ?? ''}';
    if (id.isEmpty || currentUser == null || previewMode) return;
    final queuedPayload = {...summary, '_ownerId': currentUser!.id};
    try {
      await _api.post('/offline/summaries', summary);
    } catch (_) {
      await _local.queue(
        'nearby-$id',
        'nearby_summary',
        '/offline/summaries',
        queuedPayload,
      );
    }
  }

  Future<void> _roadmapAction(Future<void> Function() action) async {
    if (previewMode) {
      statusMessage = 'Connect the local API to use this feature.';
      notifyListeners();
      return;
    }
    await _withBusy(action);
  }

  Future<List<JsonMap>> loadSessionHistory() async {
    loadingHistory = true;
    notifyListeners();
    try {
      if (previewMode)
        return [
          {
            'room_title': 'CSC 401 · Operating systems',
            'preset': 'classic',
            'focused_seconds': 4320,
            'started_at': DateTime.now().toIso8601String(),
            'task_count': 2,
          },
        ];
      final result = await _api.get('/sessions/history');
      return (result['sessions'] as List? ?? [])
          .whereType<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();
    } finally {
      loadingHistory = false;
      notifyListeners();
    }
  }

  static String sessionHistoryCsv(List<JsonMap> sessions) {
    String cell(Object? value) {
      final text = '$value';
      return '"${text.replaceAll('"', '""')}"';
    }

    final rows = <List<String>>[
      ['Started at', 'Room', 'Focus minutes', 'Tasks completed'],
      for (final session in sessions)
        [
          '${session['started_at'] ?? ''}',
          '${session['room_title'] ?? 'Study session'}',
          '${((int.tryParse('${session['focused_seconds'] ?? 0}') ?? 0) / 60).round()}',
          '${session['task_count'] ?? 0}',
        ],
    ];
    return rows.map((row) => row.map(cell).join(',')).join('\r\n');
  }

  Future<List<StudyMessage>> loadDirectMessages(String conversationId) async {
    if (previewMode)
      return const [
        StudyMessage(
          id: 'dm-preview',
          body: 'Want to meet for a study block tomorrow?',
          senderName: 'Zara',
        ),
      ];
    try {
      final result = await _api.get('/direct/$conversationId/messages');
      final raw = (result['messages'] as List? ?? []);
      await _local.cacheJson('direct_messages:$conversationId', raw);
      directMessages[conversationId] = raw
          .whereType<Map>()
          .map(
            (x) => StudyMessage.fromJson(
              x.cast<String, dynamic>(),
              currentUser?.id ?? '',
            ),
          )
          .toList();
    } catch (_) {
      final cached = await _local.readJson('direct_messages:$conversationId');
      if (cached is List) {
        directMessages[conversationId] = cached
            .whereType<Map>()
            .map(
              (x) => StudyMessage.fromJson(
                x.cast<String, dynamic>(),
                currentUser?.id ?? '',
              ),
            )
            .toList();
      }
    }
    notifyListeners();
    return directMessages[conversationId] ?? const [];
  }

  Future<void> sendDirectMessage(
    String conversationId,
    String body, {
    String? replyTo,
  }) async {
    if (previewMode) {
      statusMessage = 'Direct messages are disabled in preview mode.';
      notifyListeners();
      return;
    }
    final clientMutationId = _randomId();
    final payload = {
      'body': body,
      'replyTo': replyTo,
      'clientMutationId': clientMutationId,
    };
    final path = '/direct/$conversationId/messages';
    final optimistic = StudyMessage(
      id: clientMutationId,
      body: body,
      senderName: currentUser?.username ?? 'Me',
      isMine: true,
    );
    directMessages[conversationId] = [
      ...(directMessages[conversationId] ?? const <StudyMessage>[]),
      optimistic,
    ];
    await _cacheDirectMessages(conversationId);
    notifyListeners();
    try {
      await _api.post(path, payload);
      await loadDirectMessages(conversationId);
    } catch (error) {
      if (error is ApiException && error.statusCode != null) {
        directMessages[conversationId] = directMessages[conversationId]!
            .where((message) => message.id != clientMutationId)
            .toList();
        errorMessage = error.message;
        await _cacheDirectMessages(conversationId);
      } else {
        await _local.queue(clientMutationId, 'post', path, payload);
        statusMessage = 'Message queued on this device.';
      }
      notifyListeners();
    }
  }

  Future<void> pinDirectMessage(String conversationId, String messageId) async {
    if (previewMode) return;
    await _api.post('/direct/$conversationId/messages/$messageId/pin');
    await loadDirectMessages(conversationId);
  }

  Future<void> _cacheDirectMessages(String conversationId) async {
    final messages = directMessages[conversationId] ?? const <StudyMessage>[];
    await _local.cacheJson('direct_messages:$conversationId', [
      for (final message in messages)
        {
          'id': message.id,
          'body': message.body,
          'sender_name': message.senderName,
          'sender_id': message.isMine ? currentUser?.id : null,
          'is_pinned': message.isPinned,
          'reactions': message.reactions,
          'reply_body': message.replyBody,
        },
    ]);
  }

  Future<void> inviteUser(String username) async {
    if (previewMode || activeRoomId == null) return;
    await _withBusy(() async {
      await _api.post('/rooms/$activeRoomId/invitations', {
        'username': username,
      });
      statusMessage = 'Invitation sent.';
    });
  }

  Future<void> removeMember(String userId) async {
    if (previewMode || activeRoomId == null) return;
    await _withBusy(() async {
      await _api.delete('/rooms/$activeRoomId/members/$userId');
      await openRoom(activeRoomId!);
      statusMessage = 'Member removed from the room.';
    });
  }

  Future<void> setCohost(
    String userId,
    bool enabled, {
    List<String> permissions = const [],
  }) async {
    final roomId = activeRoomId;
    if (roomId == null || previewMode) return;
    await _withBusy(() async {
      await _api.post('/rooms/$roomId/members/$userId/cohost', {
        'enabled': enabled,
        'permissions': permissions,
      });
      await loadRoom(roomId);
      await loadMine();
      statusMessage = enabled
          ? 'Co-host permissions saved.'
          : 'Co-host role removed.';
    });
  }

  Future<void> closeRoom() async {
    if (previewMode || activeRoomId == null) return;
    final roomId = activeRoomId!;
    await _withBusy(() async {
      await _api.patch('/rooms/$roomId', {'closed': true});
      _realtime.unsubscribe(roomId);
      activeRoomId = null;
      activeRoom = {};
      await loadMine();
      statusMessage = 'Room closed.';
    });
  }

  Future<void> updateRoom({
    required String title,
    required String goal,
    required int participantLimit,
    DateTime? scheduledAt,
    String recurrence = 'none',
  }) async {
    if (previewMode || activeRoomId == null) return;
    await _withBusy(() async {
      final roomId = activeRoomId!;
      final result = await _api.patch('/rooms/$roomId', {
        'title': title,
        'goal': goal,
        'participantLimit': participantLimit,
        'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
        'recurrence': recurrence,
      });
      activeRoom = (result['room'] as Map).cast<String, dynamic>()
        ..['role'] = 'host';
      await loadMine();
      statusMessage = 'Room settings saved.';
    });
  }

  Future<void> backFromRoom() async {
    final roomId = activeRoomId;
    if (roomId != null && !previewMode) _realtime.unsubscribe(roomId);
    activeRoomId = null;
    activeRoom = {};
    roomTasks = [];
    roomMessages = [];
    _sessionTicker?.cancel();
    notifyListeners();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await markNotificationsRead([notificationId]);
  }

  Future<void> markNotificationsRead(Iterable<String> notificationIds) async {
    final ids = notificationIds.where((id) => id.isNotEmpty).toSet();
    final unreadIds = notifications
        .where(
          (item) => ids.contains('${item['id']}') && item['is_read'] != true,
        )
        .map((item) => '${item['id']}')
        .toSet();
    if (unreadIds.isEmpty) return;

    notifications = notifications
        .map(
          (item) => unreadIds.contains('${item['id']}')
              ? {...item, 'is_read': true}
              : item,
        )
        .toList();
    notifyListeners();
    await _local.cacheJson('notifications', notifications);

    if (previewMode) return;
    for (final id in unreadIds) {
      final path = '/notifications/$id/read';
      final queueId = 'notification-read:$id';
      try {
        await _api.patch(path, {});
        await _local.removePending(queueId);
      } catch (_) {
        await _local.queue(queueId, 'notification_read', path, {});
      }
    }
  }

  Future<void> addReaction(
    String kind,
    String messageId,
    String reaction,
  ) async {
    if (previewMode) return;
    await _api.post('/messages/$kind/$messageId/reactions', {
      'reaction': reaction,
    });
  }

  Future<void> pinRoomMessage(String roomId, String messageId) async {
    if (previewMode) return;
    await _api.post('/rooms/$roomId/messages/$messageId/pin');
    await loadRoomMessages(roomId);
  }

  Future<List<JsonMap>> getAdminReports() async {
    if (previewMode || currentUser?.isAdmin != true) return [];
    final result = await _api.get('/admin/reports');
    return (result['reports'] as List? ?? [])
        .whereType<Map>()
        .map((x) => x.cast<String, dynamic>())
        .toList();
  }

  Future<void> blockUser(String userId) async {
    if (previewMode) return;
    await _withBusy(() async {
      await _api.post('/users/$userId/block');
      statusMessage = 'Account blocked.';
    });
  }

  Future<void> reportUser(
    String userId,
    String reason, {
    String? roomId,
    String details = '',
  }) async {
    if (previewMode) return;
    await _withBusy(() async {
      await _api.post('/reports', {
        'reportedUserId': userId,
        'reason': reason,
        'details': details,
        'roomId': roomId,
      });
      statusMessage = 'Report sent to the aLaStudie review queue.';
    });
  }

  Future<void> reviewReport(String reportId, String action) async {
    await _withBusy(() async {
      await _api.patch('/admin/reports/$reportId', {'action': action});
      statusMessage = 'Report updated.';
    });
  }

  Future<void> syncOutbox() async {
    if (previewMode || currentUser == null) return;
    var personalTasksChanged = false;
    var roomChanged = false;
    var messagesChanged = false;
    var rejectedChange = false;
    for (final item in await _local.pending()) {
      try {
        final path = item['path']! as String;
        final payload = (jsonDecode(item['payload']! as String) as Map)
            .cast<String, dynamic>();
        if (item['kind'] == 'post' || item['kind'] == 'nearby_summary') {
          if (item['kind'] == 'nearby_summary') {
            if (payload['_ownerId'] != currentUser?.id) continue;
            payload.remove('_ownerId');
          }
          await _api.post(path, payload);
          if (RegExp(r'^/rooms/[^/]+/messages$').hasMatch(path)) {
            messagesChanged = true;
            roomChanged = true;
          }
          final directMatch = RegExp(
            r'^/direct/([^/]+)/messages$',
          ).firstMatch(path);
          if (directMatch != null) {
            await loadDirectMessages(directMatch.group(1)!);
          }
        } else {
          await _api.patch(path, payload);
          if (item['kind'] == 'personal_task') {
            personalTasksChanged = true;
          } else if (path.startsWith('/tasks/')) {
            roomChanged = true;
          }
        }
        await _local.removePending(item['id']! as String);
      } on ApiException catch (error) {
        if (error.statusCode != null) {
          await _local.removePending(item['id']! as String);
          rejectedChange = true;
          if (item['kind'] == 'personal_task') {
            personalTasksChanged = true;
          } else if ((item['path'] as String?)?.startsWith('/tasks/') == true) {
            roomChanged = true;
          } else if ((item['path'] as String?)?.contains('/messages') == true) {
            roomChanged = true;
            messagesChanged = true;
          }
        } else {
          break;
        }
      } catch (_) {
        break;
      }
    }
    if (personalTasksChanged) await loadPersonalTasks();
    if (activeRoomId != null && (roomChanged || messagesChanged)) {
      if (roomChanged) {
        try {
          await loadRoom(activeRoomId!);
        } catch (_) {}
      }
      if (messagesChanged) await loadRoomMessages(activeRoomId!);
    }
    if (rejectedChange) {
      statusMessage = 'A saved change could not be applied and was removed.';
    }
    if (personalTasksChanged ||
        roomChanged ||
        messagesChanged ||
        rejectedChange) {
      notifyListeners();
    }
  }

  Future<void> leaveRoom() async {
    if (activeRoomId == null) return;
    if (previewMode) {
      activeRoomId = null;
      activeRoom = {};
      notifyListeners();
      return;
    }
    final roomId = activeRoomId!;
    await _withBusy(() async {
      await _api.post('/rooms/$roomId/leave');
      _realtime.unsubscribe(roomId);
      activeRoomId = null;
      activeRoom = {};
      await loadMine();
    });
  }

  void setTab(int index) {
    selectedTab = index;
    if (index == 1) unawaited(loadDiscovery());
    if (index == 2) unawaited(loadMine());
    if (index == 3) unawaited(loadStats());
    notifyListeners();
  }

  void _startTicker() {
    _sessionTicker?.cancel();
    _sessionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (activeSession?.status == 'running' && sessionSeconds > 0)
        sessionSeconds--;
      if (sessionSeconds == 0 &&
          activeSession?.status == 'running' &&
          !previewMode &&
          activeRoomId != null &&
          !_refreshingSession) {
        _refreshingSession = true;
        unawaited(
          openRoom(
            activeRoomId!,
          ).whenComplete(() => _refreshingSession = false),
        );
      }
      notifyListeners();
    });
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    busy = true;
    errorMessage = null;
    statusMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      errorMessage = error is ApiException
          ? error.message
          : 'Could not reach the local API. Start PostgreSQL and the aLaStudie server, then try again.';
    }
    busy = false;
    notifyListeners();
  }

  String _randomId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';

  String _ianaTimezone() {
    final name = DateTime.now().timeZoneName;
    if (name == 'WAT') return 'Africa/Lagos';
    if (name == 'GMT' || name == 'UTC') return 'UTC';
    final offset = DateTime.now().timeZoneOffset;
    if (offset.inMinutes == 0) return 'UTC';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${offset.isNegative ? '-' : '+'}$hours:$minutes';
  }

  @override
  void dispose() {
    _sessionTicker?.cancel();
    _realtime.disconnect();
    _api.close();
    unawaited(_local.close());
    super.dispose();
  }
}
