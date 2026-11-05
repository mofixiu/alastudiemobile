import 'dart:async';

import '../../shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui.dart';
import '../app/app_controller.dart';
import 'room_resources_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({super.key, required this.roomId});
  final String roomId;
  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  double _edgeSwipeDistance = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppController>();
      if (app.activeRoomId != widget.roomId)
        unawaited(app.openRoom(widget.roomId));
    });
  }

  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) {
      final title = '${app.activeRoom['title'] ?? 'Study room'}';
      final subject = '${app.activeRoom['subject'] ?? 'Study room'}';
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          _edgeSwipeDistance =
              Theme.of(context).platform == TargetPlatform.iOS &&
                  details.localPosition.dx <= 30
              ? 0
              : -1;
        },
        onHorizontalDragUpdate: (details) {
          if (_edgeSwipeDistance >= 0) {
            _edgeSwipeDistance += details.primaryDelta ?? 0;
          }
        },
        onHorizontalDragEnd: (details) {
          final threshold = MediaQuery.sizeOf(context).width * .22;
          if (_edgeSwipeDistance > threshold ||
              (_edgeSwipeDistance >= 0 &&
                  (details.primaryVelocity ?? 0) > 650)) {
            unawaited(app.backFromRoom());
          }
          _edgeSwipeDistance = 0;
        },
        child: Scaffold(
          body: SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: [
                BrandGlassSliverBar(
                  leading: IconButton(
                    onPressed: app.backFromRoom,
                    icon: const AppIcon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  ),
                  actions: [
                    StatusTag(
                      DateTime.tryParse(
                                '${app.activeRoom['scheduled_at'] ?? ''}',
                              )?.isAfter(DateTime.now()) ==
                              true
                          ? 'SCHEDULED'
                          : 'LIVE',
                      color: context.appSoftBlue,
                      textColor: context.appInk,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _roomMenu(context, app),
                      icon: const AppIcon(Icons.more_horiz_rounded),
                      tooltip: 'Room options',
                    ),
                  ],
                  wordmarkSize: 18,
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  sliver: SliverList.list(
                    children: [
                      const SizedBox(height: 10),
                      Eyebrow(subject.toUpperCase()),
                      const SizedBox(height: 7),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${app.activeRoom['goal'] ?? 'Study together, one step at a time.'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                aLaStudieRoute(
                                  context: context,
                                  builder: (_) => RoomResourcesScreen(
                                    roomId: widget.roomId,
                                    roomTitle: title,
                                  ),
                                ),
                              ),
                              icon: const AppIcon(
                                Icons.folder_open_outlined,
                                size: 15,
                              ),
                              label: const Text('Room library'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                aLaStudieRoute(
                                  context: context,
                                  builder: (_) => RoomWhiteboardScreen(
                                    roomId: widget.roomId,
                                    roomTitle: title,
                                  ),
                                ),
                              ),
                              icon: const AppIcon(
                                Icons.draw_outlined,
                                size: 15,
                              ),
                              label: const Text('Whiteboard'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SessionCard(app: app),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: SectionHeading('The room is here'),
                          ),
                          Builder(
                            builder: (context) {
                              final mine =
                                  app.roomPresence[app.currentUser?.id ??
                                      'preview-user'] ??
                                  'away';
                              return TextButton.icon(
                                onPressed: () => _choosePresence(context, app),
                                icon: AppIcon(
                                  Icons.circle,
                                  color: _presenceColor(mine),
                                  size: 11,
                                ),
                                label: Text(_presenceLabel(mine)),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SoftPanel(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          children: [
                            for (final member in app.roomMembers)
                              _MemberRow(
                                member: member,
                                status:
                                    app.roomPresence['${member['id']}'] ??
                                    (member['id'] == app.currentUser?.id
                                        ? 'studying'
                                        : 'offline'),
                                isHost: member['role'] == 'host',
                                isCohost: member['role'] == 'cohost',
                                onReport: () =>
                                    _reportMember(context, app, member),
                              ),
                            const Divider(height: 18),
                            Row(
                              children: [
                                AppIcon(
                                  Icons.groups_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 17,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  '${app.roomMembers.length} / ${app.activeRoom['participant_limit'] ?? 8} members',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const Spacer(),
                                if (app.canManageMembers &&
                                    app.activeRoom['access_type'] == 'invite')
                                  TextButton(
                                    onPressed: () => _invite(context, app),
                                    child: const Text('Invite'),
                                  ),
                                if (app.activeRoom['access_type'] == 'public')
                                  TextButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(
                                          text: app.roomShareLink(
                                            widget.roomId,
                                          ),
                                        ),
                                      );
                                      if (context.mounted) {
                                        showAppMessage(
                                          context,
                                          'Room link copied. Anyone can find this public room in Discover.',
                                        );
                                      }
                                    },
                                    icon: const AppIcon(
                                      Icons.ios_share_rounded,
                                    ),
                                    label: const Text('Share'),
                                  ),
                              ],
                            ),
                            if (app.canManageMembers &&
                                app.activeRoom['access_type'] == 'link' &&
                                app.activeRoom['access_code'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: StatusTag(
                                    'ROOM CODE · ${app.activeRoom['access_code']}',
                                    color: context.appRaisedSurface,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 23),
                      SectionHeading(
                        'Our next steps',
                        action: 'Add task',
                        onAction: () => _addTask(context, app),
                      ),
                      const SizedBox(height: 6),
                      if (app.roomTasks.isEmpty)
                        const SoftPanel(
                          child: Text(
                            'Add one clear next step so everyone knows where to begin.',
                          ),
                        )
                      else
                        ...app.roomTasks.map(
                          (task) => _RoomTaskRow(
                            task: task,
                            onTap: () => app.toggleRoomTask(task),
                          ),
                        ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.push(
                          context,
                          aLaStudieRoute(
                            context: context,
                            builder: (_) =>
                                RoomChatScreen(roomId: widget.roomId),
                          ),
                        ),
                        child: SoftPanel(
                          color: context.appRaisedSurface,
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: context.appBrandPanel,
                                  shape: BoxShape.circle,
                                ),
                                child: const AppIcon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Room notes',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Keep the chat useful and light.',
                                      style: TextStyle(
                                        color: context.appMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (app.roomMessages.isNotEmpty)
                                Text(
                                  '${app.roomMessages.length}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              const SizedBox(width: 5),
                              const AppIcon(
                                Icons.arrow_forward_rounded,
                                color: AppColors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (app.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: InlineErrorNotice(app.errorMessage!),
                        ),
                      if (app.previewMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 13),
                          child: StatusTag(
                            'ROOM PREVIEW',
                            color: context.appSoftAccent,
                            textColor: context.appInk,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  void _roomMenu(BuildContext context, AppController app) =>
      showPremiumBottomSheet<void>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (app.canManageMembers &&
                  app.activeRoom['access_type'] == 'invite')
                PremiumListRow(
                  leading: const AppIcon(Icons.person_add_alt_1),
                  title: const Text('Invite a student'),
                  onTap: () {
                    Navigator.pop(context);
                    _invite(context, app);
                  },
                ),
              if (app.canEditRoom)
                PremiumListRow(
                  leading: const AppIcon(Icons.tune_rounded),
                  title: const Text('Edit room settings'),
                  onTap: () {
                    Navigator.pop(context);
                    _editRoom(context, app);
                  },
                ),
              if (app.isHost)
                PremiumListRow(
                  leading: const AppIcon(Icons.settings_outlined),
                  title: const Text('Close room'),
                  onTap: () async {
                    Navigator.pop(context);
                    await app.closeRoom();
                  },
                ),
              PremiumListRow(
                leading: const AppIcon(Icons.logout_rounded),
                title: const Text('Leave this room'),
                onTap: () {
                  Navigator.pop(context);
                  app.leaveRoom();
                },
              ),
            ],
          ),
        ),
      );

  void _editRoom(BuildContext context, AppController app) {
    final title = TextEditingController(
      text: '${app.activeRoom['title'] ?? ''}',
    );
    final goal = TextEditingController(text: '${app.activeRoom['goal'] ?? ''}');
    final limit = TextEditingController(
      text: '${app.activeRoom['participant_limit'] ?? 8}',
    );
    var scheduledAt =
        DateTime.tryParse(
          '${app.activeRoom['scheduled_at'] ?? ''}',
        )?.toLocal() ??
        DateTime.now().add(const Duration(hours: 1));
    var scheduleLater = app.activeRoom['scheduled_at'] != null;
    var recurrence = '${app.activeRoom['recurrence'] ?? 'none'}';

    Future<void> pickSchedule(
      BuildContext dialogContext,
      StateSetter update,
    ) async {
      final now = DateTime.now();
      final selected = await showBrandedDateTimePicker(
        context: dialogContext,
        initialDateTime: scheduledAt.isBefore(now) ? now : scheduledAt,
        minimumDate: now,
        maximumDate: DateTime(now.year + 2, now.month, now.day, 23, 55),
        eyebrow: 'ROOM SCHEDULE',
        title: 'When should it meet?',
        confirmLabel: 'Set room time',
      );
      if (selected == null || !dialogContext.mounted) return;
      if (!selected.isAfter(DateTime.now())) {
        showAppMessage(dialogContext, 'Choose a start time in the future.');
        return;
      }
      update(() {
        scheduledAt = selected;
      });
    }

    showBrandedDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => PremiumDialogSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('ROOM SETTINGS'),
              const SizedBox(height: 5),
              Text(
                'Edit room',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 13),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: title,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Room name',
                        ),
                      ),
                      TextField(
                        controller: goal,
                        maxLength: 240,
                        decoration: const InputDecoration(
                          labelText: 'Study goal',
                        ),
                      ),
                      TextField(
                        controller: limit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Member limit (2–50)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              const Eyebrow('ROOM START'),
              Wrap(
                spacing: 7,
                children: [
                  PremiumChoiceChip(
                    label: const Text('Start now'),
                    selected: !scheduleLater,
                    selectedColor: context.appSoftBlue,
                    onSelected: (_) => setDialogState(() {
                      scheduleLater = false;
                      recurrence = 'none';
                    }),
                  ),
                  PremiumChoiceChip(
                    label: const Text('Schedule'),
                    selected: scheduleLater,
                    selectedColor: context.appSoftBlue,
                    onSelected: (_) =>
                        setDialogState(() => scheduleLater = true),
                  ),
                ],
              ),
              if (scheduleLater) ...[
                OutlinedButton.icon(
                  onPressed: () => pickSchedule(context, setDialogState),
                  icon: const AppIcon(Icons.calendar_month_outlined),
                  label: Text(
                    '${MaterialLocalizations.of(context).formatMediumDate(scheduledAt)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(scheduledAt))}',
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 7,
                  children: [
                    for (final option in [
                      ('Never', 'none'),
                      ('Daily', 'daily'),
                      ('Weekly', 'weekly'),
                    ])
                      PremiumChoiceChip(
                        label: Text(option.$1),
                        selected: recurrence == option.$2,
                        selectedColor: context.appSoftBlue,
                        onSelected: (_) => setDialogState(() {
                          recurrence = option.$2;
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await app.updateRoom(
                        title: title.text.trim(),
                        goal: goal.text.trim(),
                        participantLimit: int.tryParse(limit.text) ?? 8,
                        scheduledAt: scheduleLater ? scheduledAt : null,
                        recurrence: scheduleLater ? recurrence : 'none',
                      );
                      if (context.mounted) {
                        showAppMessage(
                          context,
                          app.statusMessage ?? app.errorMessage,
                        );
                      }
                      title.dispose();
                      goal.dispose();
                      limit.dispose();
                    },
                    child: const Text('Save changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _choosePresence(BuildContext context, AppController app) async {
    final current =
        app.roomPresence[app.currentUser?.id ?? 'preview-user'] ?? 'away';
    final selected = await showPremiumBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('ROOM PRESENCE'),
              const SizedBox(height: 5),
              Text(
                'Set your status',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              for (final item in [
                ('studying', 'Studying', Icons.menu_book_outlined),
                ('break', 'On break', Icons.coffee_outlined),
                ('away', 'Away', Icons.airline_seat_recline_normal_rounded),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(sheetContext, item.$1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: item.$1 == current
                            ? context.appRaisedSurface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            AppIcon(item.$3, color: _presenceColor(item.$1)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(item.$2)),
                            if (item.$1 == current)
                              const AppIcon(Icons.check_rounded, size: 19),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    app.setPresence(selected);
    if (context.mounted) {
      showAppMessage(
        context,
        'Your room status is ${_presenceLabel(selected).toLowerCase()}.',
      );
    }
  }

  String _presenceLabel(String status) => switch (status) {
    'studying' => 'Studying',
    'break' => 'On break',
    'offline' => 'Offline',
    _ => 'Away',
  };

  Color _presenceColor(String status) => switch (status) {
    'studying' => AppColors.marine2,
    'break' => AppColors.red,
    'offline' => const Color(0xFF8B8B8B),
    _ => const Color(0xFFB0743D),
  };

  void _addTask(BuildContext context, AppController app) {
    final controller = TextEditingController();
    showPremiumBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('SHARED WITH THE ROOM'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Add a clear next step',
              ),
            ),
            const SizedBox(height: 14),
            PrimaryAction(
              label: 'Add task',
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                app.createRoomTask(controller.text.trim());
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _invite(BuildContext context, AppController app) {
    final controller = TextEditingController();
    showBrandedDialog<void>(
      context: context,
      builder: (context) => PremiumDialogSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('GROW THE ROOM'),
            const SizedBox(height: 5),
            Text(
              'Invite a student',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 13),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                prefixText: '@',
                hintText: 'username',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await app.inviteUser(controller.text.replaceFirst('@', ''));
                    if (context.mounted) {
                      showAppMessage(
                        context,
                        app.statusMessage ?? app.errorMessage,
                      );
                    }
                  },
                  icon: const AppIcon(Icons.send_rounded),
                  label: const Text('Send invite'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _reportMember(BuildContext context, AppController app, JsonMap member) {
    if (member['id'] == app.currentUser?.id) return;
    showPremiumBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PremiumListRow(
              title: Text('About @${member['username']}'),
              subtitle: const Text('Choose an action for this room member.'),
            ),
            PremiumListRow(
              leading: const AppIcon(Icons.flag_outlined),
              title: const Text('Report account'),
              onTap: () {
                Navigator.pop(context);
                app.reportUser(
                  '${member['id']}',
                  'inappropriate_room_behavior',
                  roomId: widget.roomId,
                );
              },
            ),
            PremiumListRow(
              leading: const AppIcon(Icons.block_outlined),
              title: const Text('Block account'),
              onTap: () {
                Navigator.pop(context);
                app.blockUser('${member['id']}');
              },
            ),
            if (app.isHost && member['role'] != 'host')
              PremiumListRow(
                leading: AppIcon(
                  member['role'] == 'cohost'
                      ? Icons.tune_rounded
                      : Icons.shield_outlined,
                ),
                title: Text(
                  member['role'] == 'cohost'
                      ? 'Edit co-host permissions'
                      : 'Make co-host',
                ),
                subtitle: const Text(
                  'Choose the room jobs they can handle. Timer control stays with you.',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _editCohost(context, app, member);
                },
              ),
            if (app.canManageMembers && member['role'] != 'host')
              PremiumListRow(
                leading: const AppIcon(Icons.person_remove_outlined),
                title: const Text('Remove from room'),
                onTap: () {
                  Navigator.pop(context);
                  app.removeMember('${member['id']}');
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCohost(
    BuildContext context,
    AppController app,
    JsonMap member,
  ) async {
    const choices = <(String, String, String)>[
      ('manage_members', 'Members', 'Invite and remove people'),
      (
        'manage_room',
        'Room details',
        'Edit the room title, goal, and capacity',
      ),
      ('manage_schedule', 'Schedule', 'Move or cancel individual meetings'),
      ('manage_attendance', 'Attendance', 'Mark attendance for other members'),
      ('moderate_chat', 'Chat pins', 'Pin and unpin useful messages'),
    ];
    final current = member['permissions'];
    final selected = <String>{
      if (current is Map)
        for (final entry in current.entries)
          if (entry.value == true) '${entry.key}',
    };
    final change = await showPremiumBottomSheet<_CohostChange>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('ROOM TRUST, ON PURPOSE'),
                const SizedBox(height: 6),
                Text(
                  'Co-host access',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  '@${member['username']} · choose each responsibility',
                  style: TextStyle(color: context.appMuted),
                ),
                const SizedBox(height: 10),
                for (final choice in choices)
                  PremiumCheckboxRow(
                    value: selected.contains(choice.$1),
                    onChanged: (enabled) => setSheetState(() {
                      if (enabled == true) {
                        selected.add(choice.$1);
                      } else {
                        selected.remove(choice.$1);
                      }
                    }),
                    title: Text(
                      choice.$2,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(choice.$3),
                    contentPadding: EdgeInsets.zero,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (member['role'] == 'cohost')
                      TextButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          const _CohostChange(enabled: false),
                        ),
                        child: const Text('Remove co-host'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        sheetContext,
                        _CohostChange(
                          enabled: true,
                          permissions: selected.toList(),
                        ),
                      ),
                      child: const Text('Save access'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (change == null || !context.mounted) return;
    await app.setCohost(
      '${member['id']}',
      change.enabled,
      permissions: change.permissions,
    );
    if (context.mounted) {
      showAppMessage(context, app.statusMessage ?? app.errorMessage);
    }
  }
}

class _CohostChange {
  const _CohostChange({required this.enabled, this.permissions = const []});
  final bool enabled;
  final List<String> permissions;
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) {
    final session = app.activeSession;
    final startsAt = DateTime.tryParse(
      '${app.activeRoom['scheduled_at'] ?? ''}',
    );
    final waitingForSchedule =
        startsAt != null && startsAt.isAfter(DateTime.now());
    final seconds = app.sessionSeconds;
    final minutesText = (seconds ~/ 60).toString().padLeft(2, '0');
    final secondsText = (seconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: context.appBrandPanel,
        borderRadius: BorderRadius.circular(27),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Eyebrow(
                session?.phase == 'break' ? 'REST YOUR EYES' : 'FOCUS SESSION',
                color: context.appAccentMuted,
              ),
              const Spacer(),
              StatusTag(
                session?.status == 'paused'
                    ? 'PAUSED'
                    : session == null
                    ? 'READY'
                    : 'LIVE',
                color: session == null ? context.appSoftAccent : AppColors.red,
                textColor: session == null ? context.appInk : Colors.white,
                icon: session == null ? Icons.circle_outlined : Icons.circle,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                session == null ? '25:00' : '$minutesText:$secondsText',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 54,
                  height: .96,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.3,
                  fontFeatures: [],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  session?.phase == 'break' ? 'break' : 'focus',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            waitingForSchedule
                ? 'Session opens ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(startsAt.toLocal()))}.'
                : session == null
                ? 'Start a shared timer when the room is ready.'
                : 'Block ${session.cycle} · ${session.preset.toUpperCase()}',
            style: TextStyle(
              color: Colors.white.withOpacity(.74),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: PrimaryAction(
                  label: session == null
                      ? 'Start focus'
                      : session.status == 'paused'
                      ? 'Resume timer'
                      : 'Pause timer',
                  color: AppColors.red,
                  icon: session == null
                      ? Icons.play_arrow_rounded
                      : session.status == 'paused'
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  onPressed: !app.isHost || waitingForSchedule
                      ? null
                      : () {
                          if (session == null)
                            _chooseSession(context, app);
                          else
                            app.controlSession(
                              session.status == 'paused' ? 'resume' : 'pause',
                            );
                        },
                ),
              ),
              if (session != null && app.isHost) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => app.controlSession('finish'),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(.16),
                    foregroundColor: Colors.white,
                  ),
                  icon: const AppIcon(Icons.stop_rounded),
                  tooltip: 'Finish session',
                ),
              ],
            ],
          ),
          if (session != null && !app.isHost)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'The host controls this shared timer.',
                style: TextStyle(
                  color: Colors.white.withOpacity(.7),
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _chooseSession(BuildContext context, AppController app) =>
      showPremiumBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('PICK YOUR RHYTHM'),
                const SizedBox(height: 8),
                Text(
                  'Start together.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                for (final choice in [
                  ('classic', 'Classic', '25 min focus · 5 min break'),
                  ('deep', 'Deep focus', '50 min focus · 10 min break'),
                  ('custom', 'Set my own', 'Choose a room pace'),
                ])
                  PremiumListRow(
                    contentPadding: EdgeInsets.zero,
                    leading: AppIcon(
                      choice.$1 == 'classic'
                          ? Icons.bolt_rounded
                          : choice.$1 == 'deep'
                          ? Icons.brightness_2_outlined
                          : Icons.tune_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      choice.$2,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(choice.$3),
                    onTap: () async {
                      Navigator.pop(context);
                      if (choice.$1 == 'custom') {
                        final values = await _customDurations(context);
                        if (values != null)
                          await app.startSession(
                            preset: 'custom',
                            focusMinutes: values.$1,
                            breakMinutes: values.$2,
                          );
                      } else {
                        await app.startSession(preset: choice.$1);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      );

  Future<(int, int)?> _customDurations(BuildContext context) async {
    final focus = TextEditingController(text: '40');
    final rest = TextEditingController(text: '8');
    final result = await showBrandedDialog<(int, int)>(
      context: context,
      builder: (context) => PremiumDialogSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('YOUR OWN PACE'),
            const SizedBox(height: 5),
            Text(
              'Set the room rhythm',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: focus,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Focus min'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: rest,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Break min'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, (
                    int.tryParse(focus.text) ?? 25,
                    int.tryParse(rest.text) ?? 5,
                  )),
                  child: const Text('Start'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    focus.dispose();
    rest.dispose();
    return result;
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.status,
    required this.isHost,
    required this.isCohost,
    required this.onReport,
  });
  final JsonMap member;
  final String status;
  final bool isHost;
  final bool isCohost;
  final VoidCallback onReport;
  @override
  Widget build(BuildContext context) {
    final color = status == 'studying'
        ? Theme.of(context).colorScheme.primary
        : status == 'break'
        ? const Color(0xFFBD7C24)
        : status == 'away'
        ? context.appMuted
        : context.appLine;
    final label = switch (status) {
      'studying' => 'Studying',
      'break' => 'On break',
      'away' => 'Away',
      _ => 'Offline',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          InitialAvatar(
            initial: '${member['username'] ?? '?'}',
            size: 32,
            backgroundColor: color.withValues(alpha: .14),
            foregroundColor: color,
            fontSize: 11,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${member['username'] ?? 'Student'}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          if (isHost)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: StatusTag(
                'HOST',
                color: context.appSoftAccent,
                textColor: context.appInk,
              ),
            ),
          if (isCohost)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: StatusTag(
                'CO-HOST',
                color: AppColors.red,
                textColor: Colors.white,
              ),
            ),
          AppIcon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: context.appMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            onPressed: onReport,
            visualDensity: VisualDensity.compact,
            icon: AppIcon(
              Icons.more_horiz_rounded,
              size: 18,
              color: context.appMuted,
            ),
            tooltip: 'Member actions',
          ),
        ],
      ),
    );
  }
}

class _RoomTaskRow extends StatelessWidget {
  const _RoomTaskRow({required this.task, required this.onTap});
  final StudyTask task;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appLine)),
      ),
      child: Row(
        children: [
          AppIcon(
            task.completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: task.completed
                ? Theme.of(context).colorScheme.primary
                : context.appMuted,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (task.memberCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${task.completedCount}/${task.memberCount} have finished this',
                      style: TextStyle(color: context.appMuted, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
          AppIcon(
            Icons.drag_indicator_rounded,
            size: 18,
            color: context.appMuted,
          ),
        ],
      ),
    ),
  );
}

class RoomChatScreen extends StatefulWidget {
  const RoomChatScreen({super.key, required this.roomId});
  final String roomId;
  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> {
  final input = TextEditingController();
  String? replyId;

  void _messageActions(AppController app, StudyMessage message) {
    showPremiumBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PremiumListRow(
              leading: const AppIcon(Icons.reply_rounded),
              title: const Text('Reply to this note'),
              onTap: () {
                Navigator.pop(context);
                setState(() => replyId = message.id);
              },
            ),
            PremiumListRow(
              leading: const Text('❤️', style: TextStyle(fontSize: 20)),
              title: const Text('React with a heart'),
              onTap: () async {
                Navigator.pop(context);
                await app.addReaction('room', message.id, '❤️');
                await app.loadRoomMessages(widget.roomId);
              },
            ),
            if (app.canModerateRoomChat)
              PremiumListRow(
                leading: AppIcon(
                  message.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(message.isPinned ? 'Unpin note' : 'Pin note'),
                onTap: () {
                  Navigator.pop(context);
                  app.pinRoomMessage(widget.roomId, message.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AppController>().loadRoomMessages(widget.roomId),
    );
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) => Scaffold(
      appBar: BrandRouteHeader(
        eyebrow: 'ROOM CHAT',
        title: 'Useful, not noisy',
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                BrandRefreshSliver(
                  onRefresh: () => app.loadRoomMessages(widget.roomId),
                ),
                if (app.roomMessages.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyNotice(
                      title: 'Start with a useful note',
                      body:
                          'Ask a study question, share a resource, or encourage the room.',
                      icon: Icons.chat_bubble_outline_rounded,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList.builder(
                      itemCount: app.roomMessages.length,
                      itemBuilder: (context, index) {
                        final m = app.roomMessages[index];
                        return GestureDetector(
                          onLongPress: () => _messageActions(app, m),
                          child: Align(
                            alignment: m.isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 11),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width * .8,
                              ),
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: m.isMine
                                    ? context.appBrandPanel
                                    : context.appSurface,
                                border: Border.all(
                                  color: m.isMine
                                      ? context.appBrandPanel
                                      : context.appLine,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(17),
                                  topRight: const Radius.circular(17),
                                  bottomLeft: Radius.circular(
                                    m.isMine ? 17 : 4,
                                  ),
                                  bottomRight: Radius.circular(
                                    m.isMine ? 4 : 17,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!m.isMine)
                                    Text(
                                      m.senderName,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  if (m.isPinned) const Eyebrow('PINNED'),
                                  if (m.replyBody != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: Text(
                                        '↳ ${m.replyBody}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: m.isMine
                                              ? Colors.white70
                                              : context.appMuted,
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    m.body,
                                    style: TextStyle(
                                      color: m.isMine
                                          ? Colors.white
                                          : context.appInk,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (m.reactions.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        m.reactions.join('  '),
                                        style: TextStyle(
                                          color: m.isMine
                                              ? Colors.white70
                                              : context.appMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (replyId != null)
            PremiumListRow(
              dense: true,
              title: const Text('Replying to a room note'),
              trailing: IconButton(
                onPressed: () => setState(() => replyId = null),
                icon: const AppIcon(Icons.close),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Share something useful…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      final body = input.text.trim();
                      if (body.isEmpty) return;
                      app.sendRoomMessage(body, replyTo: replyId);
                      input.clear();
                      setState(() => replyId = null);
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const AppIcon(Icons.arrow_upward_rounded),
                    tooltip: 'Send message',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
