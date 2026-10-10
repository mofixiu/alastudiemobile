import 'dart:async';

import '../../shared/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui.dart';
import '../app/app_controller.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get _monthStart => DateTime(_visibleMonth.year, _visibleMonth.month);
  DateTime get _nextMonthStart =>
      DateTime(_visibleMonth.year, _visibleMonth.month + 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          context.read<AppController>().loadCalendar(
            from: _monthStart,
            to: _nextMonthStart,
          ),
        );
      }
    });
  }

  void _moveMonth(AppController app, int amount) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + amount,
      );
    });
    unawaited(app.loadCalendar(from: _monthStart, to: _nextMonthStart));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, app, _) {
        final occurrences = [...app.calendarOccurrences]
          ..sort(
            (a, b) => (DateTime.tryParse('${a['starts_at']}') ?? DateTime(2100))
                .compareTo(
                  DateTime.tryParse('${b['starts_at']}') ?? DateTime(2100),
                ),
          );
        return CupertinoPageScaffold(
          backgroundColor: context.appPaper,
          child: SafeArea(
            top: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                BrandRefreshSliver(
                  onRefresh: () =>
                      app.loadCalendar(from: _monthStart, to: _nextMonthStart),
                ),
                BrandGlassSliverBar(
                  leading: _CalendarIconAction(
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                    onTap: () => Navigator.maybePop(context),
                  ),
                  actions: [
                    if (app.loadingCalendar) ...[
                      const SizedBox(width: 8),
                      const _CalendarSyncMark(),
                    ],
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 13, 18, 22),
                  sliver: SliverList.list(
                    children: [
                      const _CalendarHero(),
                      const SizedBox(height: 14),
                      SoftPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            _CalendarIconAction(
                              icon: Icons.arrow_back_ios_new_rounded,
                              label: 'Previous month',
                              onTap: () => _moveMonth(app, -1),
                            ),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(.06, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                child: Column(
                                  key: ValueKey(
                                    '${_visibleMonth.year}-${_visibleMonth.month}',
                                  ),
                                  children: [
                                    Text(
                                      _monthName(
                                        _visibleMonth.month,
                                      ).toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .08,
                                      ),
                                    ),
                                    Text(
                                      '${_visibleMonth.year}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.appMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _CalendarIconAction(
                              icon: Icons.arrow_forward_ios_rounded,
                              label: 'Next month',
                              onTap: () => _moveMonth(app, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SectionHeading('Meetings this month'),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                if (app.loadingCalendar && occurrences.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 44),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _CalendarSyncMark(expanded: true),
                            const SizedBox(height: 14),
                            Text(
                              'Laying out the next few meetings…',
                              style: TextStyle(color: context.appMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (occurrences.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyNotice(
                      title: 'Nothing scheduled yet',
                      body:
                          app.errorMessage ??
                          'No meetings are on the calendar for ${_monthName(_visibleMonth.month)} yet. Try another month or schedule one in My rooms.',
                      icon: Icons.calendar_month_outlined,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                    sliver: SliverList.builder(
                      itemCount: occurrences.length,
                      itemBuilder: (context, index) => OneShotReveal(
                        key: ValueKey(occurrences[index]['id']),
                        index: index,
                        distance: 12,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _OccurrenceCard(
                            occurrence: occurrences[index],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({required this.occurrence});
  final Map<String, dynamic> occurrence;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final start = DateTime.tryParse('${occurrence['starts_at']}')?.toLocal();
    final status = '${occurrence['status'] ?? 'scheduled'}';
    final rsvp = '${occurrence['my_rsvp'] ?? ''}';
    final reminder = occurrence['reminder_enabled'] == true;
    final attended = occurrence['attended'] == true;
    final canManage = occurrence['can_manage'] == true;
    final canManageAttendance = occurrence['can_manage_attendance'] == true;
    final canReschedule = occurrence['can_reschedule'] == true;
    final membership = app.myRooms.any(
      (room) => room.id == occurrence['room_id'],
    );
    final checkInOpen =
        start != null &&
        DateTime.now().isAfter(start.subtract(const Duration(hours: 1))) &&
        DateTime.now().isBefore(start.add(const Duration(hours: 4)));
    final timeLabel = start == null
        ? 'Time to be confirmed'
        : '${_weekday(start.weekday)} · ${_date(start)} · ${_clockTime(start)}';

    return SoftPanel(
      color: context.appSurface,
      borderColor: status == 'cancelled' ? AppColors.red : context.appLine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 58,
                decoration: BoxDecoration(
                  color: status == 'cancelled'
                      ? AppColors.red
                      : context.appBrandPanel,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(9),
                    bottomLeft: Radius.circular(9),
                    bottomRight: Radius.circular(17),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  start == null ? '—' : '${start.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(
                      '${occurrence['subject'] ?? 'STUDY ROOM'} · ${occurrence['host_name'] ?? 'HOST'}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${occurrence['room_title'] ?? 'Study room'}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        color: context.appMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (status == 'cancelled')
                const StatusTag(
                  'CANCELLED',
                  color: AppColors.red,
                  textColor: Colors.white,
                ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              AppIcon(
                Icons.group_outlined,
                size: 17,
                color: context.appBrandInk,
              ),
              const SizedBox(width: 6),
              Text(
                '${occurrence['going_count'] ?? 0} going',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 14),
              AppIcon(
                Icons.fact_check_outlined,
                size: 17,
                color: context.appBrandInk,
              ),
              const SizedBox(width: 6),
              Text(
                '${occurrence['attendance_count'] ?? 0} attended',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (rsvp == 'going' && reminder)
                const AppIcon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: AppColors.red,
                ),
            ],
          ),
          if (status != 'cancelled') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                _rsvpChip(
                  context,
                  app,
                  'going',
                  'I’m going',
                  rsvp == 'going',
                  true,
                ),
                _rsvpChip(
                  context,
                  app,
                  'maybe',
                  'Maybe',
                  rsvp == 'maybe',
                  false,
                ),
                _rsvpChip(
                  context,
                  app,
                  'declined',
                  'Can’t make it',
                  rsvp == 'declined',
                  false,
                ),
              ],
            ),
            if (rsvp == 'going')
              _CalendarAction(
                label: reminder ? '24-hour reminder on' : 'Turn on a reminder',
                icon: reminder
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
                onTap: app.busy
                    ? null
                    : () async {
                        await app.rsvpOccurrence(
                          '${occurrence['id']}',
                          status: 'going',
                          reminderEnabled: !reminder,
                        );
                        if (context.mounted && app.statusMessage != null) {
                          showAppMessage(context, app.statusMessage);
                        } else if (context.mounted &&
                            app.errorMessage != null) {
                          showAppMessage(context, app.errorMessage);
                        }
                      },
              ),
            if (membership && !attended)
              _CalendarAction(
                label: checkInOpen
                    ? 'Check in for this meeting'
                    : 'Check-in opens near start time',
                icon: Icons.how_to_reg_rounded,
                onTap: !checkInOpen || app.busy
                    ? null
                    : () async {
                        await app.checkInOccurrence('${occurrence['id']}');
                        if (context.mounted && app.errorMessage != null)
                          showAppMessage(context, app.errorMessage);
                      },
              ),
            if (canManageAttendance)
              _CalendarAction(
                label: checkInOpen
                    ? 'Mark a member present'
                    : 'Member attendance opens near start time',
                icon: Icons.fact_check_outlined,
                onTap: !checkInOpen || app.busy
                    ? null
                    : () => _markRoomAttendance(context, app),
              ),
            if (attended)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: StatusTag(
                  'ATTENDED',
                  color: AppColors.red,
                  textColor: Colors.white,
                ),
              ),
            if (canManage && start != null && start.isAfter(DateTime.now()))
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canReschedule)
                    _CalendarAction(
                      label: 'Reschedule',
                      icon: Icons.edit_calendar_outlined,
                      onTap: app.busy
                          ? null
                          : () => _reschedule(context, app, start),
                    ),
                  _CalendarAction(
                    label: 'Cancel',
                    icon: Icons.event_busy_outlined,
                    onTap: app.busy ? null : () => _cancel(context, app),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _rsvpChip(
    BuildContext context,
    AppController app,
    String value,
    String label,
    bool selected,
    bool reminder,
  ) => _CalendarAction(
    label: label,
    icon: selected ? Icons.check_rounded : null,
    selected: selected,
    onTap: app.busy
        ? null
        : () async {
            await app.rsvpOccurrence(
              '${occurrence['id']}',
              status: value,
              reminderEnabled: reminder,
            );
            if (context.mounted && app.statusMessage != null) {
              showAppMessage(context, app.statusMessage);
            } else if (context.mounted && app.errorMessage != null) {
              showAppMessage(context, app.errorMessage);
            }
          },
  );

  Future<void> _cancel(BuildContext context, AppController app) async {
    await app.cancelOccurrence('${occurrence['id']}');
    if (context.mounted)
      showAppMessage(context, app.errorMessage ?? app.statusMessage);
  }

  Future<void> _reschedule(
    BuildContext context,
    AppController app,
    DateTime currentStart,
  ) async {
    final earliest = DateTime.now().add(const Duration(minutes: 5));
    DateTime selected = alignDateTimeToMinuteInterval(
      value: currentStart.isAfter(earliest) ? currentStart : earliest,
      minimum: earliest,
      maximum: DateTime.now().add(const Duration(days: 730)),
    );
    final startsAt = await showPremiumBottomSheet<DateTime>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Eyebrow('MOVE THIS MEETING ONLY'),
                const SizedBox(height: 5),
                Text(
                  'Pick a new start',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  'Other dates in this repeating room stay put.',
                  style: TextStyle(color: context.appMuted, fontSize: 12),
                ),
                SizedBox(
                  height: 210,
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: context.appIsDark
                          ? Brightness.dark
                          : Brightness.light,
                      primaryColor: AppColors.red,
                      scaffoldBackgroundColor: context.appPaper,
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.dateAndTime,
                      initialDateTime: selected,
                      minimumDate: earliest,
                      maximumDate: DateTime.now().add(
                        const Duration(days: 730),
                      ),
                      minuteInterval: 5,
                      onDateTimeChanged: (value) => setSheetState(() {
                        selected = value;
                      }),
                    ),
                  ),
                ),
                PrimaryAction(
                  label: 'Move this occurrence',
                  icon: Icons.event_available_rounded,
                  onPressed: () => Navigator.pop(sheetContext, selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!context.mounted || startsAt == null) return;
    if (!startsAt.isAfter(DateTime.now())) {
      showAppMessage(context, 'Choose a time in the future.');
      return;
    }
    await app.rescheduleOccurrence('${occurrence['id']}', startsAt);
    if (context.mounted) {
      showAppMessage(context, app.errorMessage ?? app.statusMessage);
    }
  }

  Future<void> _markRoomAttendance(
    BuildContext context,
    AppController app,
  ) async {
    final attendees = (occurrence['attendance_members'] as List? ?? [])
        .whereType<Map>()
        .map((member) => member.cast<String, dynamic>())
        .toList();
    await showPremiumBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('THIS MEETING ONLY'),
              const SizedBox(height: 5),
              Text(
                'Take attendance',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 9),
              if (attendees.isEmpty)
                const Text('No room members are available yet.')
              else
                for (final member in attendees)
                  _AttendanceMemberRow(
                    username: '${member['username']}',
                    attended: member['attended'] == true,
                    onTap: member['attended'] == true
                        ? null
                        : () async {
                            Navigator.pop(sheetContext);
                            await app.checkInOccurrence(
                              '${occurrence['id']}',
                              userId: '${member['id']}',
                            );
                            if (context.mounted) {
                              showAppMessage(
                                context,
                                app.errorMessage ??
                                    'Attendance marked for @${member['username']}.',
                              );
                            }
                          },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  String _weekday(int day) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];
  String _date(DateTime date) => '${date.month}/${date.day}';
  String _clockTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }
}

class _CalendarIconAction extends StatelessWidget {
  const _CalendarIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: context.appRaisedSurface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: context.appLine),
        ),
        alignment: Alignment.center,
        child: AppIcon(icon, size: 17, color: context.appInk),
      ),
    ),
  );
}

class _CalendarHero extends StatelessWidget {
  const _CalendarHero();

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 152),
    padding: const EdgeInsets.fromLTRB(18, 17, 16, 17),
    decoration: BoxDecoration(
      color: context.appBrandPanel,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(27),
        topRight: Radius.circular(19),
        bottomLeft: Radius.circular(19),
        bottomRight: Radius.circular(27),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Eyebrow('YOUR STUDY ROOM LINEUP', color: AppColors.mint),
              const SizedBox(height: 8),
              Text(
                'Show up\ntogether.',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  height: .99,
                  fontSize: 29,
                  letterSpacing: -1.05,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'RSVP, reminders, and attendance—meeting by meeting.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .78),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Transform.rotate(
          angle: -.1,
          child: Container(
            width: 62,
            height: 82,
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CalendarAction extends StatelessWidget {
  const _CalendarAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : context.appInk;
    final background = selected ? AppColors.red : context.appRaisedSurface;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: onTap == null
                ? background.withValues(alpha: .55)
                : background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.red : context.appLine,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppIcon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceMemberRow extends StatelessWidget {
  const _AttendanceMemberRow({
    required this.username,
    required this.attended,
    required this.onTap,
  });

  final String username;
  final bool attended;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      button: !attended,
      label: attended ? '@$username, present' : 'Mark @$username present',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appLine),
          ),
          child: Row(
            children: [
              AppIcon(Icons.person_outline_rounded, color: context.appBrandInk),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '@$username',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (attended)
                const StatusTag(
                  'PRESENT',
                  color: AppColors.red,
                  textColor: Colors.white,
                )
              else
                AppIcon(Icons.add_task_rounded, color: context.appBrandInk),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CalendarSyncMark extends StatelessWidget {
  const _CalendarSyncMark({this.expanded = false});
  final bool expanded;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: expanded ? 64 : 36,
    height: 5,
    child: Row(
      children: [
        Expanded(
          flex: expanded ? 5 : 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.appBrandInk,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      ],
    ),
  );
}

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];
