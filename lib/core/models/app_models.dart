typedef JsonMap = Map<String, dynamic>;

String formatProfileSubjects(
  dynamic value, {
  String separator = ' · ',
  String emptyValue = 'Add a few interests',
}) {
  final List<String> values;
  if (value is Iterable) {
    values = value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  } else if (value is String) {
    values = value
        .split(RegExp(r'[,·]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  } else {
    values = const [];
  }
  return values.isEmpty ? emptyValue : values.join(separator);
}

class DailyFocus {
  const DailyFocus({required this.day, required this.focusedSeconds});
  final DateTime day;
  final int focusedSeconds;

  String get weekday =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
}

List<DailyFocus> lastSevenDays(JsonMap stats, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final localToday = DateTime(today.year, today.month, today.day);
  final recorded = <String, int>{};
  for (final row in (stats['days'] as List? ?? []).whereType<Map>()) {
    final value = row.cast<String, dynamic>();
    final date = DateTime.tryParse('${value['day'] ?? ''}');
    if (date == null) continue;
    final key = _dayKey(date);
    recorded[key] = int.tryParse('${value['focusedSeconds'] ?? 0}') ?? 0;
  }
  return List.generate(7, (index) {
    final day = localToday.subtract(Duration(days: 6 - index));
    return DailyFocus(day: day, focusedSeconds: recorded[_dayKey(day)] ?? 0);
  });
}

String _dayKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.username,
    this.profile = const {},
    this.isAdmin = false,
  });
  final String id;
  final String email;
  final String username;
  final JsonMap profile;
  final bool isAdmin;

  factory AppUser.fromJson(JsonMap json) => AppUser(
    id: '${json['id'] ?? ''}',
    email: '${json['email'] ?? ''}',
    username: '${json['username'] ?? 'student'}',
    profile: (json['profile'] as Map?)?.cast<String, dynamic>() ?? const {},
    isAdmin: json['is_admin'] == true || json['isAdmin'] == true,
  );
}

class StudyRoom {
  const StudyRoom({
    required this.id,
    required this.title,
    required this.subject,
    required this.goal,
    this.course = '',
    this.accessType = 'public',
    this.hostName = 'Study host',
    this.memberCount = 1,
    this.participantLimit = 8,
    this.isMember = false,
    this.role = 'member',
    this.accessCode,
    this.scheduledAt,
    this.recurrence = 'none',
  });
  final String id;
  final String title;
  final String subject;
  final String goal;
  final String course;
  final String accessType;
  final String hostName;
  final int memberCount;
  final int participantLimit;
  final bool isMember;
  final String role;
  final String? accessCode;
  final DateTime? scheduledAt;
  final String recurrence;

  bool get isScheduled => scheduledAt != null;

  String get scheduleSummary {
    final start = scheduledAt?.toLocal();
    if (start == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);
    final date = day == today
        ? 'Today'
        : day == today.add(const Duration(days: 1))
        ? 'Tomorrow'
        : const [
            'Mon',
            'Tue',
            'Wed',
            'Thu',
            'Fri',
            'Sat',
            'Sun',
          ][start.weekday - 1];
    final hour = start.hour % 12 == 0 ? 12 : start.hour % 12;
    final minute = start.minute.toString().padLeft(2, '0');
    final meridiem = start.hour < 12 ? 'AM' : 'PM';
    final repeat = switch (recurrence) {
      'daily' => ' · DAILY',
      'weekly' => ' · WEEKLY',
      _ => '',
    };
    final timing = recurrence == 'none'
        ? (start.isAfter(now) ? 'STARTS' : 'STARTED')
        : (start.isAfter(now) ? 'NEXT' : 'MEETS');
    return '$timing $date · $hour:$minute $meridiem$repeat';
  }

  factory StudyRoom.fromJson(JsonMap json) => StudyRoom(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? 'Study room'}',
    subject: '${json['subject'] ?? 'Study'}',
    goal: '${json['goal'] ?? ''}',
    course: '${json['course'] ?? ''}',
    accessType: '${json['access_type'] ?? json['accessType'] ?? 'public'}',
    hostName: '${json['host_name'] ?? json['hostName'] ?? 'Study host'}',
    memberCount:
        int.tryParse('${json['member_count'] ?? json['memberCount'] ?? 1}') ??
        1,
    participantLimit:
        int.tryParse(
          '${json['participant_limit'] ?? json['participantLimit'] ?? 8}',
        ) ??
        8,
    isMember: json['is_member'] == true || json['isMember'] == true,
    role: '${json['role'] ?? 'member'}',
    accessCode: json['accessCode'] as String?,
    scheduledAt: DateTime.tryParse(
      '${json['scheduled_at'] ?? json['scheduledAt'] ?? ''}',
    ),
    recurrence: '${json['recurrence'] ?? 'none'}',
  );
}

class StudyTask {
  const StudyTask({
    required this.id,
    required this.title,
    this.completed = false,
    this.completedCount = 0,
    this.memberCount = 0,
    this.personal = false,
  });
  final String id;
  final String title;
  final bool completed;
  final int completedCount;
  final int memberCount;
  final bool personal;

  factory StudyTask.fromJson(JsonMap json, {String? userId}) {
    final completions =
        (json['completions'] as List?)?.whereType<Map>().toList() ?? const [];
    final mine = completions
        .where((x) => x['userId'] == userId || x['user_id'] == userId)
        .toList();
    return StudyTask(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'Study task'}',
      completed:
          json['completed_at'] != null ||
          (mine.isNotEmpty &&
              (mine.first['completedAt'] != null ||
                  mine.first['completed_at'] != null)),
      completedCount: completions
          .where((x) => x['completedAt'] != null || x['completed_at'] != null)
          .length,
      memberCount: completions.length,
      personal: json['is_personal'] == true,
    );
  }
}

class StudyMessage {
  const StudyMessage({
    required this.id,
    required this.body,
    required this.senderName,
    this.isMine = false,
    this.isPinned = false,
    this.reactions = const [],
    this.replyBody,
    this.createdAt,
  });
  final String id;
  final String body;
  final String senderName;
  final bool isMine;
  final bool isPinned;
  final List<String> reactions;
  final String? replyBody;
  final DateTime? createdAt;

  factory StudyMessage.fromJson(JsonMap json, String userId) => StudyMessage(
    id: '${json['id'] ?? json['client_mutation_id'] ?? ''}',
    body: '${json['body'] ?? ''}',
    senderName: '${json['sender_name'] ?? json['senderName'] ?? 'Student'}',
    isMine: json['sender_id'] == userId || json['senderId'] == userId,
    isPinned: json['is_pinned'] == true,
    reactions: ((json['reactions'] as List?) ?? const [])
        .map((e) => e is Map ? '${e['reaction']}' : '$e')
        .toList(),
    replyBody: json['reply_body'] as String?,
    createdAt: DateTime.tryParse(
      '${json['created_at'] ?? json['createdAt'] ?? ''}',
    ),
  );
}

class StudySession {
  const StudySession({
    required this.id,
    required this.phase,
    required this.status,
    required this.remainingSeconds,
    this.preset = 'classic',
    this.hostId = '',
    this.cycle = 1,
  });
  final String id;
  final String phase;
  final String status;
  final int remainingSeconds;
  final String preset;
  final String hostId;
  final int cycle;

  factory StudySession.fromJson(JsonMap json) => StudySession(
    id: '${json['id'] ?? ''}',
    phase: '${json['phase'] ?? 'focus'}',
    status: '${json['status'] ?? 'finished'}',
    remainingSeconds:
        int.tryParse(
          '${json['remainingSeconds'] ?? json['remaining_seconds'] ?? 0}',
        ) ??
        0,
    preset: '${json['preset'] ?? 'classic'}',
    hostId: '${json['hostId'] ?? json['host_id'] ?? ''}',
    cycle: int.tryParse('${json['cycle'] ?? 1}') ?? 1,
  );
}
