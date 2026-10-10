import 'dart:async';

import '../../shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui.dart';
import '../app/app_controller.dart';
import '../calendar/calendar_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) => CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        BrandRefreshSliver(onRefresh: app.refreshHome),
        BrandGlassSliverBar(
          actions: [
            IconButton(
              tooltip: 'Study calendar',
              onPressed: () => Navigator.push(
                context,
                aLaStudieRoute(
                  context: context,
                  builder: (_) => const CalendarScreen(),
                ),
              ),
              icon: const AppIcon(Icons.calendar_month_outlined, size: 21),
            ),
            Stack(
              children: [
                IconButton(
                  onPressed: () => _showNotifications(context, app),
                  icon: const AppIcon(
                    Icons.notifications_none_rounded,
                    size: 22,
                  ),
                  tooltip: 'Notifications',
                ),
                if (app.notifications.any((n) => n['is_read'] != true))
                  const Positioned(
                    right: 8,
                    top: 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 8, height: 8),
                    ),
                  ),
              ],
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          sliver: SliverList.list(
            children: [
              Text(
                'Hey, ${app.displayName.split(' ').first}.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 18),
              BrandFeaturePanel(
                eyebrow: 'FOCUS IS BETTER IN COMPANY',
                title: 'Find your\nstudy people.',
                description: 'Pick a room. Settle into the work.',
                actionLabel: 'Explore rooms',
                onAction: () => app.setTab(1),
                titleSize: 35,
                titleWidthFactor: .74,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: SectionHeading('A good place to begin'),
                  ),
                  TextButton(
                    onPressed: () => app.setTab(1),
                    child: const Text('All rooms'),
                  ),
                ],
              ),
              if (app.discoveryRooms.isEmpty && app.loadingDiscovery)
                SoftPanel(
                  color: context.appSurface,
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Finding rooms…'),
                    ],
                  ),
                )
              else if (app.discoveryRooms.isEmpty)
                SoftPanel(
                  color: context.appSurface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppIcon(
                            app.discoveryUnavailable
                                ? Icons.wifi_off_rounded
                                : Icons.groups_2_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              app.discoveryUnavailable
                                  ? 'Rooms could not load right now. Pull down to try again.'
                                  : 'No public rooms yet. Start one and invite someone to join.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!app.discoveryUnavailable)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => app.setTab(2),
                            icon: const AppIcon(Icons.add_rounded),
                            label: const Text('Go to My rooms'),
                          ),
                        ),
                    ],
                  ),
                )
              else
                ...app.discoveryRooms
                    .take(2)
                    .map(
                      (room) => Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: DiscoverRoomCard(
                          room: room,
                          onTap: () => openRoom(context, app, room),
                        ),
                      ),
                    ),
              const SizedBox(height: 13),
              if (app.loadingStats && app.stats.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              Row(
                children: [
                  Expanded(
                    child: _StreakCard(
                      days:
                          int.tryParse('${app.stats['streakDays'] ?? 4}') ?? 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FocusCard(
                      seconds:
                          int.tryParse(
                            '${app.stats['focusedSeconds30Days'] ?? 0}',
                          ) ??
                          0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              SectionHeading(
                'A small plan, just for you',
                action: 'Add task',
                onAction: () => _addPersonalTask(context, app),
              ),
              const SizedBox(height: 10),
              if (app.personalTasks.isEmpty && app.loadingPersonalTasks)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (app.personalTasks.isEmpty)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _addPersonalTask(context, app),
                  child: SoftPanel(
                    child: Row(
                      children: [
                        AppIcon(
                          Icons.add_task_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add one thing you want to finish today',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final task in app.personalTasks.take(3))
                  _TaskRow(
                    task: task,
                    onTap: () => app.togglePersonalTask(task),
                  ),
              if (app.previewMode)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: StatusTag(
                    'LOCAL PREVIEW · NO ACCOUNT',
                    color: context.appSoftAccent,
                    textColor: context.appInk,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  static Future<void> openRoom(
    BuildContext context,
    AppController app,
    StudyRoom room,
  ) async {
    if (room.isMember || app.myRooms.any((r) => r.id == room.id)) {
      await app.openRoom(room.id);
      return;
    }
    var code = '';
    if (room.accessType == 'link') {
      final result = await showRoomCodePrompt(context);
      if (result == null || result.isEmpty) return;
      code = result;
    }
    await app.joinRoom(room, accessCode: code);
    if (app.errorMessage != null && context.mounted) {
      showAppMessage(context, app.errorMessage);
    } else if (context.mounted) {
      showAppMessage(context, app.statusMessage);
    }
  }

  static void _addPersonalTask(BuildContext context, AppController app) {
    showBrandedBottomSheet<void>(
      context: context,
      builder: (_) => _PersonalTaskSheet(app: app),
    );
  }

  static void _showNotifications(BuildContext context, AppController app) {
    final notifications = app.notifications.take(6).map((item) {
      if (item['is_read'] == true) return item;
      return {...item, 'is_read': true};
    }).toList();
    unawaited(
      app.markNotificationsRead(
        notifications
            .where((item) => item['is_read'] != true)
            .map((item) => '${item['id']}'),
      ),
    );
    showPremiumBottomSheet<void>(
      context: context,
      maxHeightFactor: .82,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('ACTIVITY'),
          const SizedBox(height: 5),
          Text(
            'Your updates.',
            style: Theme.of(sheetContext).textTheme.headlineLarge,
          ),
          const SizedBox(height: 13),
          if (notifications.isEmpty)
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: sheetContext.appBrandPanel,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                children: [
                  AppIcon(Icons.bolt_rounded, color: AppColors.red, size: 21),
                  SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'You’re all caught up.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var index = 0; index < notifications.length; index++)
              TweenAnimationBuilder<double>(
                key: ValueKey(notifications[index]['id'] ?? index),
                tween: Tween(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(sheetContext)
                    ? Duration.zero
                    : Duration(milliseconds: 300 + 55 * index),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 13),
                    child: child,
                  ),
                ),
                child: _NotificationCard(notification: notifications[index]),
              ),
        ],
      ),
    );
  }
}

class _PersonalTaskSheet extends StatefulWidget {
  const _PersonalTaskSheet({required this.app});
  final AppController app;

  @override
  State<_PersonalTaskSheet> createState() => _PersonalTaskSheetState();
}

class _PersonalTaskSheetState extends State<_PersonalTaskSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await widget.app.createPersonalTask(title);
    if (!mounted) return;
    setState(() => _submitting = false);
    final error = widget.app.errorMessage;
    if (error != null) {
      showAppMessage(context, error);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Added to your plan.')),
    );
  }

  @override
  Widget build(BuildContext context) => PremiumSheetSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('PRIVATE PLAN · JUST YOU'),
        const SizedBox(height: 5),
        Text('Name one win.', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 5),
        Text(
          'A clear next step beats a perfect plan.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.appMuted),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 100,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: 'What do you want to finish?',
            prefixIcon: AppIcon(Icons.flag_outlined),
            counterText: '',
          ),
        ),
        const SizedBox(height: 9),
        PrimaryAction(
          label: 'Add to my plan',
          icon: Icons.arrow_outward_rounded,
          busy: _submitting,
          onPressed: _controller.text.trim().isEmpty || _submitting
              ? null
              : _submit,
        ),
      ],
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});
  final JsonMap notification;

  @override
  Widget build(BuildContext context) {
    final unread = notification['is_read'] != true;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: context.appLine),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: unread ? AppColors.red : context.appSoftBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: AppIcon(
              unread ? Icons.bolt_rounded : Icons.check_rounded,
              color: unread ? Colors.white : context.appInk,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${notification['title'] ?? 'aLaStudie update'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if ('${notification['body'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${notification['body']}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: context.appMuted),
                  ),
                ],
              ],
            ),
          ),
          if (unread)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.days});
  final int days;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    height: 124,
    decoration: BoxDecoration(
      color: AppColors.red,
      borderRadius: BorderRadius.circular(23),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppIcon(
          Icons.local_fire_department_rounded,
          color: Colors.white,
          size: 21,
        ),
        const Spacer(),
        Text(
          '$days days',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 23,
            letterSpacing: -.5,
          ),
        ),
        const Text(
          'showing up',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.seconds});
  final int seconds;
  @override
  Widget build(BuildContext context) {
    final hours = seconds <= 0 ? 11 : seconds ~/ 3600;
    final minutes = seconds <= 0 ? 28 : (seconds % 3600) ~/ 60;
    return Container(
      padding: const EdgeInsets.all(16),
      height: 124,
      decoration: BoxDecoration(
        color: context.appSoftAccent,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            Icons.hourglass_bottom_rounded,
            color: context.appInk,
            size: 20,
          ),
          const Spacer(),
          Text(
            '${hours}h ${minutes}m',
            style: TextStyle(
              color: context.appInk,
              fontWeight: FontWeight.w900,
              fontSize: 21,
              letterSpacing: -.6,
            ),
          ),
          Text(
            'focus this month',
            style: TextStyle(
              color: context.appInk,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onTap});
  final StudyTask task;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
            size: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: task.completed ? TextDecoration.lineThrough : null,
                color: task.completed ? context.appMuted : context.appInk,
              ),
            ),
          ),
          if (task.personal) const Eyebrow('MINE'),
        ],
      ),
    ),
  );
}

class DiscoverRoomCard extends StatelessWidget {
  const DiscoverRoomCard({
    super.key,
    required this.room,
    required this.onTap,
    this.featured = false,
  });
  final StudyRoom room;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final foreground = featured ? Colors.white : context.appInk;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SoftPanel(
        color: featured ? context.appBrandPanel : context.appSurface,
        borderColor: featured ? context.appBrandPanel : context.appLine,
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Eyebrow(
                    room.subject,
                    color: featured ? context.appAccentMuted : context.appMuted,
                  ),
                ),
                StatusTag(
                  room.accessType == 'public'
                      ? 'OPEN'
                      : room.accessType.toUpperCase(),
                  color: room.accessType == 'public'
                      ? context.appSoftBlue
                      : context.appRaisedSurface,
                  textColor: room.accessType == 'public'
                      ? context.appInk
                      : Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              room.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              room.goal,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: featured
                    ? Colors.white.withValues(alpha: .74)
                    : context.appMuted,
              ),
            ),
            if (room.isScheduled) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  AppIcon(
                    Icons.calendar_month_outlined,
                    size: 15,
                    color: featured ? context.appAccentMuted : context.appMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      room.scheduleSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: featured ? Colors.white : context.appMuted,
                        letterSpacing: .45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                AppIcon(
                  Icons.groups_2_outlined,
                  size: 17,
                  color: featured
                      ? context.appAccentMuted
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  '${room.memberCount}/${room.participantLimit}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: foreground),
                ),
                const Spacer(),
                Text(
                  room.isMember ? 'OPEN ROOM' : 'JOIN ROOM',
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(width: 5),
                const AppIcon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
