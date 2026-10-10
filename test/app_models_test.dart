import 'package:flutter_test/flutter_test.dart';
import 'package:alastudie/core/models/app_models.dart';
import 'package:alastudie/features/app/app_controller.dart';

void main() {
  group('MVP response models', () {
    test('profile subjects safely format old text and current list values', () {
      expect(
        formatProfileSubjects('Biology, Chemistry · Maths'),
        'Biology · Chemistry · Maths',
      );
      expect(
        formatProfileSubjects(['Biology', ' ', 'Chemistry']),
        'Biology · Chemistry',
      );
      expect(formatProfileSubjects(null), 'Add a few interests');
    });

    test('room maps API access and membership fields', () {
      final room = StudyRoom.fromJson({
        'id': 'room-1',
        'title': 'Quiet study block',
        'subject': 'Biology',
        'goal': 'Review cells',
        'access_type': 'invite',
        'host_name': 'Zara',
        'member_count': 3,
        'participant_limit': 8,
        'is_member': true,
        'role': 'member',
      });

      expect(room.accessType, 'invite');
      expect(room.hostName, 'Zara');
      expect(room.memberCount, 3);
      expect(room.participantLimit, 8);
      expect(room.isMember, isTrue);
    });

    test('room maps scheduled start and repeat pattern', () {
      final start = DateTime.now().add(const Duration(days: 3));
      final room = StudyRoom.fromJson({
        'id': 'room-scheduled',
        'title': 'Weekly library table',
        'subject': 'Study hall',
        'goal': 'Read together',
        'scheduled_at': start.toUtc().toIso8601String(),
        'recurrence': 'weekly',
      });

      expect(room.isScheduled, isTrue);
      expect(room.recurrence, 'weekly');
      expect(room.scheduleSummary, startsWith('NEXT '));
      expect(room.scheduleSummary, contains('WEEKLY'));
    });

    test('shared task shows only the signed-in member completion', () {
      final task = StudyTask.fromJson({
        'id': 'task-1',
        'title': 'Finish problem set',
        'completions': [
          {'userId': 'student-a', 'completedAt': '2026-10-08T10:00:00Z'},
          {'user_id': 'student-b', 'completed_at': null},
        ],
      }, userId: 'student-a');

      expect(task.completed, isTrue);
      expect(task.completedCount, 1);
      expect(task.memberCount, 2);
      expect(task.personal, isFalse);
    });

    test('personal task maps completion without exposing shared members', () {
      final task = StudyTask.fromJson({
        'id': 'private-1',
        'title': 'Read chapter 4',
        'is_personal': true,
        'completed_at': '2026-10-08T10:00:00Z',
      }, userId: 'student-a');

      expect(task.completed, isTrue);
      expect(task.personal, isTrue);
      expect(task.memberCount, 0);
    });

    test('message maps replies, pins, reactions, and ownership', () {
      final message = StudyMessage.fromJson({
        'id': 'message-1',
        'body': 'I found the answer',
        'sender_id': 'student-a',
        'sender_name': 'Mofi',
        'reply_body': 'Which question?',
        'is_pinned': true,
        'reactions': [
          {'reaction': '👏', 'userId': 'student-b'},
        ],
        'created_at': '2026-10-08T10:00:00Z',
      }, 'student-a');

      expect(message.isMine, isTrue);
      expect(message.isPinned, isTrue);
      expect(message.replyBody, 'Which question?');
      expect(message.reactions, ['👏']);
      expect(message.createdAt, DateTime.utc(2026, 10, 8, 10));
    });

    test('session maps host-led timer state and preset', () {
      final session = StudySession.fromJson({
        'id': 'session-1',
        'phase': 'focus',
        'status': 'running',
        'remaining_seconds': 1500,
        'preset': 'classic',
        'host_id': 'host-1',
        'cycle': 2,
      });

      expect(session.remainingSeconds, 1500);
      expect(session.hostId, 'host-1');
      expect(session.preset, 'classic');
      expect(session.cycle, 2);
    });
  });

  test(
    'weekly focus values are seven local days and missing days are zero',
    () {
      final days = lastSevenDays({
        'days': [
          {'day': '2026-10-04', 'focusedSeconds': 600},
          {'day': '2026-10-08', 'focusedSeconds': 1500},
          {'day': '2026-10-09', 'focusedSeconds': 1200},
        ],
      }, now: DateTime(2026, 10, 9, 18));

      expect(days, hasLength(7));
      expect(days.first.day, DateTime(2026, 10, 3));
      expect(days.first.focusedSeconds, 0);
      expect(days[1].focusedSeconds, 600);
      expect(days[5].focusedSeconds, 1500);
      expect(days.last.weekday, 'Fri');
      expect(days.last.focusedSeconds, 1200);
    },
  );

  test('study history exports as correctly escaped private CSV', () {
    final csv = AppController.sessionHistoryCsv([
      {
        'started_at': '2026-10-09T10:00:00Z',
        'room_title': 'Biology, "no panic"',
        'focused_seconds': 2700,
        'task_count': 3,
      },
    ]);
    expect(
      csv.split('\r\n').first,
      '"Started at","Room","Focus minutes","Tasks completed"',
    );
    expect(csv, contains('"Biology, ""no panic""","45","3"'));
  });
}
