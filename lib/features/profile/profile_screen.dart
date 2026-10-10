import '../../shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui.dart';
import '../app/app_controller.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  final _displayName = TextEditingController();
  final _school = TextEditingController();
  final _subjects = TextEditingController();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppController>();
    _displayName.text = '${app.currentUser?.profile['displayName'] ?? ''}';
    _school.text = '${app.currentUser?.profile['school'] ?? ''}';
    final subjects = app.currentUser?.profile['subjects'];
    _subjects.text = formatProfileSubjects(
      subjects,
      separator: ', ',
      emptyValue: '',
    );
  }

  @override
  void dispose() {
    _displayName.dispose();
    _school.dispose();
    _subjects.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) {
      final focused =
          int.tryParse('${app.stats['focusedSeconds30Days'] ?? 0}') ?? 0;
      return CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          BrandRefreshSliver(
            onRefresh: () async {
              await app.loadStats();
              await app.loadDirectData();
            },
          ),
          BrandGlassSliverBar(
            actions: [
              IconButton(
                tooltip: 'Settings',
                onPressed: () => Navigator.push(
                  context,
                  aLaStudieRoute(
                    context: context,
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                icon: const AppIcon(Icons.settings_outlined),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
            sliver: SliverList.list(
              children: [
                const SizedBox(height: 2),
                const Eyebrow('YOUR STUDY LIFE'),
                const SizedBox(height: 5),
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 15),
                OneShotReveal(index: 1, child: _ProfileCard(app: app)),
                const SizedBox(height: 15),
                if (app.loadingStats && app.stats.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                OneShotReveal(
                  index: 3,
                  distance: 10,
                  child: Row(
                    children: [
                      Expanded(
                        child: _metric(
                          context,
                          '${app.stats['streakDays'] ?? (app.previewMode ? 4 : 0)}',
                          'DAY STREAK',
                          AppColors.red,
                          Colors.white,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _metric(
                          context,
                          _timeLabel(focused),
                          'FOCUSED · 30 DAYS',
                          context.appBrandPanel,
                          context.appBrandInk,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _metric(
                          context,
                          '${app.myRooms.length}',
                          'MY ROOMS',
                          context.appSoftAccent,
                          context.appInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OneShotReveal(
                  index: 4,
                  distance: 8,
                  child: _WeeklyFocusCard(stats: app.stats),
                ),
                const SizedBox(height: 22),
                OneShotReveal(
                  index: 5,
                  distance: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeading(
                        'Profile details',
                        action: _editing ? 'Cancel' : 'Edit',
                        onAction: () => setState(() => _editing = !_editing),
                      ),
                      const SizedBox(height: 9),
                      if (_editing)
                        SoftPanel(
                          child: Column(
                            children: [
                              _profileField(
                                'DISPLAY NAME',
                                _displayName,
                                'What should people call you?',
                              ),
                              _profileField('SCHOOL', _school, 'Optional'),
                              _profileField(
                                'SUBJECTS',
                                _subjects,
                                'Separate with commas',
                              ),
                              const SizedBox(height: 8),
                              PrimaryAction(
                                label: 'Save my profile',
                                onPressed: () async {
                                  await app.updateProfile(
                                    displayName: _displayName.text,
                                    school: _school.text,
                                    subjects: _subjects.text,
                                    publicProfile:
                                        app
                                            .currentUser
                                            ?.profile['visibility'] ==
                                        'public',
                                    allowMessageRequests:
                                        app
                                            .currentUser
                                            ?.profile['allowMessageRequests'] !=
                                        false,
                                  );
                                  if (context.mounted &&
                                      app.errorMessage == null) {
                                    setState(() => _editing = false);
                                  }
                                },
                              ),
                            ],
                          ),
                        )
                      else
                        _ProfileDetailsCard(user: app.currentUser),
                    ],
                  ),
                ),
                const SizedBox(height: 23),
                if (app.roomInvitations.isNotEmpty) ...[
                  const SectionHeading('Private room invitations'),
                  const SizedBox(height: 8),
                  for (final invitation in app.roomInvitations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: SoftPanel(
                        color: context.appSurface,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(
                              'FROM @${invitation['host_name'] ?? 'host'}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${invitation['title'] ?? 'Study room'}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${invitation['subject'] ?? 'Study'} · ${invitation['goal'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => app.dismissRoomInvitation(
                                    '${invitation['room_id']}',
                                  ),
                                  child: const Text('Decline'),
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: () => app.acceptRoomInvitation(
                                    '${invitation['room_id']}',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.red,
                                  ),
                                  icon: const AppIcon(
                                    Icons.arrow_forward_rounded,
                                  ),
                                  label: const Text('Join room'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                SectionHeading(
                  'Message requests',
                  action: 'New',
                  onAction: () => _newMessageRequest(context, app),
                ),
                const SizedBox(height: 8),
                if (app.directRequests
                    .where((r) => r['status'] == 'pending')
                    .isEmpty)
                  SoftPanel(
                    color: context.appRaisedSurface,
                    child: Row(
                      children: [
                        AppIcon(
                          Icons.mark_chat_unread_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Requests wait here until you accept.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final request in app.directRequests.where(
                    (r) => r['status'] == 'pending',
                  ))
                    _RequestCard(request: request),
                if (app.conversations.isNotEmpty || app.previewMode) ...[
                  const SizedBox(height: 20),
                  const SectionHeading('Conversations'),
                  const SizedBox(height: 7),
                  if (app.previewMode)
                    PremiumListRow(
                      contentPadding: EdgeInsets.zero,
                      leading: const InitialAvatar(
                        initial: 'Z',
                        size: 40,
                        backgroundColor: AppColors.mint,
                      ),
                      title: const Text('Zara'),
                      subtitle: const Text(
                        'Want to meet for a study block tomorrow?',
                      ),
                      trailing: const AppIcon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        aLaStudieRoute(
                          context: context,
                          builder: (_) => const DirectChatScreen(
                            conversationId: 'preview',
                            otherName: 'Zara',
                          ),
                        ),
                      ),
                    )
                  else
                    for (final conversation in app.conversations)
                      PremiumListRow(
                        contentPadding: EdgeInsets.zero,
                        leading: InitialAvatar(
                          initial: '${conversation['other_username'] ?? 'S'}',
                          size: 40,
                          backgroundColor: AppColors.mint,
                        ),
                        title: Text(
                          '@${conversation['other_username'] ?? 'student'}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text('Direct conversation'),
                        trailing: const AppIcon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          aLaStudieRoute(
                            context: context,
                            builder: (_) => DirectChatScreen(
                              conversationId: '${conversation['id']}',
                              otherName: '${conversation['other_username']}',
                              otherUserId: '${conversation['other_id']}',
                            ),
                          ),
                        ),
                      ),
                ],
                if (app.currentUser?.isAdmin == true) ...[
                  const SizedBox(height: 23),
                  const SectionHeading('Staff tools'),
                  const SizedBox(height: 8),
                  PremiumListRow(
                    tileColor: context.appSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: AppIcon(
                      Icons.shield_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Review reports'),
                    subtitle: const Text('Private moderation queue'),
                    onTap: () => _showAdminReports(context, app),
                  ),
                ],
                if (app.statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      app.statusMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (app.previewMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: StatusTag(
                      'PREVIEW · DATA IS SAMPLE ONLY',
                      color: context.appSoftAccent,
                      textColor: context.appInk,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _metric(
    BuildContext context,
    String value,
    String label,
    Color bg,
    Color fg,
  ) => Container(
    height: 91,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(19),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final settle = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: settle,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, .12),
                  end: Offset.zero,
                ).animate(settle),
                child: child,
              ),
            );
          },
          child: Text(
            value,
            key: ValueKey(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -.7,
            ),
          ),
        ),
        Text(
          label,
          maxLines: 2,
          style: TextStyle(
            color: fg.withOpacity(.75),
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
      ],
    ),
  );
  String _timeLabel(int seconds) => seconds <= 0 ? '0h' : '${seconds ~/ 3600}h';
  Widget _profileField(
    String label,
    TextEditingController controller,
    String hint,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    ),
  );
  void _newMessageRequest(BuildContext context, AppController app) {
    final username = TextEditingController();
    showBrandedDialog<void>(
      context: context,
      builder: (context) => PremiumDialogSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('A CONSIDERATE HELLO'),
            const SizedBox(height: 5),
            Text(
              'Start a message request',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: username,
              decoration: const InputDecoration(
                prefixText: '@',
                hintText: 'username',
              ),
            ),
            const SizedBox(height: 13),
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
                    await app.requestDirectMessage(
                      username.text.replaceFirst('@', ''),
                    );
                    if (context.mounted) {
                      showAppMessage(
                        context,
                        app.statusMessage ?? app.errorMessage,
                      );
                    }
                  },
                  icon: const AppIcon(Icons.arrow_outward_rounded),
                  label: const Text('Send request'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdminReports(
    BuildContext context,
    AppController app,
  ) async {
    List<JsonMap> reports = [];
    try {
      reports = await app.getAdminReports();
    } catch (error) {
      if (context.mounted) showAppMessage(context, '$error');
      return;
    }
    if (!context.mounted) return;
    showPremiumBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('STAFF ONLY'),
                const SizedBox(height: 6),
                Text(
                  'Report queue',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                if (reports.isEmpty)
                  const Expanded(
                    child: EmptyNotice(
                      title: 'Nothing to review',
                      body: 'New reports will appear here.',
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: [
                        for (final report in reports)
                          SoftPanel(
                            color: context.appSurface,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@${report['reported_name'] ?? 'student'} · ${report['status']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${report['reason']} · ${report['details'] ?? ''}',
                                ),
                                Wrap(
                                  children: [
                                    for (final action in [
                                      'warned',
                                      'suspended',
                                      'dismissed',
                                    ])
                                      TextButton(
                                        onPressed: () async {
                                          await app.reviewReport(
                                            '${report['id']}',
                                            action,
                                          );
                                          if (context.mounted)
                                            Navigator.pop(context);
                                        },
                                        child: Text(action.toUpperCase()),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyFocusCard extends StatelessWidget {
  const _WeeklyFocusCard({required this.stats});
  final JsonMap stats;

  @override
  Widget build(BuildContext context) {
    final days = lastSevenDays(stats);
    final weekSeconds = days.fold<int>(
      0,
      (sum, day) => sum + day.focusedSeconds,
    );
    final peak = days.fold<int>(
      0,
      (largest, day) =>
          day.focusedSeconds > largest ? day.focusedSeconds : largest,
    );
    return SoftPanel(
      color: context.appSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(child: Eyebrow('LAST 7 DAYS')),
              Text(
                '${_focusDuration(weekSeconds)} FOCUSED',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in days)
                Expanded(
                  child: Semantics(
                    label:
                        '${day.weekday}, ${_focusDuration(day.focusedSeconds)} focused',
                    child: Tooltip(
                      message:
                          '${day.weekday} · ${_focusDuration(day.focusedSeconds)} focused',
                      child: Column(
                        children: [
                          SizedBox(
                            height: 62,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 5,
                                  end: peak == 0
                                      ? 5
                                      : 5 + (day.focusedSeconds / peak * 54),
                                ),
                                duration: const Duration(milliseconds: 620),
                                curve: Curves.easeOutCubic,
                                builder: (context, height, _) => Container(
                                  width: 18,
                                  height: height,
                                  decoration: BoxDecoration(
                                    color:
                                        day.day.day == DateTime.now().day &&
                                            day.day.month ==
                                                DateTime.now().month &&
                                            day.day.year == DateTime.now().year
                                        ? AppColors.red
                                        : Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            day.weekday,
                            style: TextStyle(
                              color: context.appMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _focusDuration(int seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.appBrandPanel,
      borderRadius: BorderRadius.circular(25),
    ),
    child: Row(
      children: [
        InitialAvatar(
          initial: app.displayName.isEmpty ? 'A' : app.displayName,
          size: 50,
          backgroundColor: context.appSoftAccent,
          fontSize: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.displayName,
                style: TextStyle(
                  color: context.appBrandInk,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '@${app.currentUser?.username} · ${app.currentUser?.email}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const AppIcon(Icons.menu_book_rounded, color: AppColors.red),
      ],
    ),
  );
}

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final profile = user?.profile ?? const <String, dynamic>{};
    final displayName = '${profile['displayName'] ?? ''}'.trim();
    final school = '${profile['school'] ?? ''}'.trim();
    final subjectSummary = formatProfileSubjects(
      profile['subjects'],
      emptyValue: '',
    );
    final subjects = subjectSummary.isEmpty
        ? const <String>[]
        : subjectSummary.split(' · ');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: context.appLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100D2D3A),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: context.appRaisedSurface,
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.appBrandPanel,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: AppIcon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: context.appBrandInk,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('YOUR INTRO'),
                      const SizedBox(height: 3),
                      Text(
                        displayName.isEmpty
                            ? 'Add a display name'
                            : displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 21,
                          height: 1.05,
                          letterSpacing: -.45,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 8,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('SCHOOL'),
                const SizedBox(height: 3),
                Text(
                  school.isEmpty ? 'Add your school' : school,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: context.appLine),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Eyebrow('STUDYING')),
                    if (subjects.isNotEmpty)
                      Text(
                        '${subjects.length.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: context.appMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                if (subjects.isEmpty)
                  Text(
                    'Add subjects you like to study.',
                    style: TextStyle(color: context.appMuted, fontSize: 12),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final subject in subjects)
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width - 94,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: context.appSoftBlue,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: context.appLine.withOpacity(.8),
                            ),
                          ),
                          child: Text(
                            subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appInk,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    const AppIcon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: AppColors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PRIVATE BY DEFAULT',
                      style: TextStyle(
                        color: context.appMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.05,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final JsonMap request;
  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: SoftPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${request['sender_name'] ?? 'student'} wants to connect',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        app.respondToRequest('${request['id']}', false),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        app.respondToRequest('${request['id']}', true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.conversationId,
    required this.otherName,
    this.otherUserId = '',
  });
  final String conversationId;
  final String otherName;
  final String otherUserId;
  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final input = TextEditingController();
  List<StudyMessage> messages = [];
  bool busy = true;
  String? replyId;
  bool _showMentionSuggestion = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    messages = await context.read<AppController>().loadDirectMessages(
      widget.conversationId,
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  String get _mentionHandle => widget.otherName.replaceFirst('@', '').trim();

  void _onDraftChanged(String value) {
    final cursor = input.selection.isValid
        ? input.selection.extentOffset
        : value.length;
    final draft = value.substring(0, cursor.clamp(0, value.length));
    final show = RegExp(r'(^|\s)@[A-Za-z0-9_]*$').hasMatch(draft);
    if (_showMentionSuggestion != show) {
      setState(() => _showMentionSuggestion = show);
    }
  }

  void _insertMention() {
    final text = input.text;
    final cursor = input.selection.isValid
        ? input.selection.extentOffset.clamp(0, text.length)
        : text.length;
    final before = text.substring(0, cursor);
    final at = before.lastIndexOf('@');
    final replaceFrom =
        at >= 0 && (at == 0 || RegExp(r'\s').hasMatch(before[at - 1]))
        ? at
        : cursor;
    final prefix = text.substring(0, replaceFrom);
    final suffix = text.substring(cursor);
    final next = '$prefix@$_mentionHandle $suffix';
    input.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: (prefix + '@$_mentionHandle ').length,
      ),
    );
    setState(() => _showMentionSuggestion = false);
  }

  void _showAccountActions(AppController app) {
    showPremiumBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PremiumListRow(
              leading: const AppIcon(Icons.block_outlined),
              title: const Text('Block account'),
              subtitle: const Text('You will no longer receive messages.'),
              onTap: () async {
                Navigator.pop(context);
                await app.blockUser(widget.otherUserId);
                if (mounted && app.statusMessage != null) {
                  showAppMessage(context, app.statusMessage);
                }
              },
            ),
            PremiumListRow(
              leading: const AppIcon(Icons.flag_outlined),
              title: const Text('Report account'),
              subtitle: const Text('Send this account to staff for review.'),
              onTap: () async {
                Navigator.pop(context);
                await app.reportUser(
                  widget.otherUserId,
                  'inappropriate_message',
                );
                if (mounted && app.statusMessage != null) {
                  showAppMessage(context, app.statusMessage);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBody(BuildContext context, StudyMessage message) {
    final base = message.isMine ? Colors.white : context.appInk;
    final mention = message.isMine
        ? context.appAccentMuted
        : Theme.of(context).colorScheme.secondary;
    final handle = RegExp.escape(_mentionHandle);
    final expression = RegExp(
      '@$handle(?=\$|[^A-Za-z0-9_])',
      caseSensitive: false,
    );
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in expression.allMatches(message.body)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: message.body.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: mention, fontWeight: FontWeight.w900),
        ),
      );
      cursor = match.end;
    }
    if (cursor < message.body.length) {
      spans.add(TextSpan(text: message.body.substring(cursor)));
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(color: base),
        children: spans.isEmpty ? [TextSpan(text: message.body)] : spans,
      ),
    );
  }

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
              leading: AppIcon(
                message.isPinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                message.isPinned ? 'Unpin this note' : 'Pin this note',
              ),
              onTap: () async {
                Navigator.pop(context);
                await app.pinDirectMessage(widget.conversationId, message.id);
                await _load();
              },
            ),
            PremiumListRow(
              leading: const Text('❤️', style: TextStyle(fontSize: 20)),
              title: const Text('React with a heart'),
              onTap: () async {
                Navigator.pop(context);
                await app.addReaction('direct', message.id, '❤️');
                await _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final visibleMessages =
        app.directMessages[widget.conversationId] ?? messages;
    return Scaffold(
      appBar: BrandRouteHeader(
        eyebrow: 'DIRECT MESSAGE',
        title: '@${widget.otherName}',
        actions: [
          if (widget.otherUserId.isNotEmpty)
            IconButton(
              tooltip: 'Account actions',
              onPressed: () => _showAccountActions(app),
              icon: const AppIcon(Icons.more_horiz_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: busy
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (visibleMessages.isEmpty)
                        const EmptyNotice(
                          title: 'A considerate hello goes a long way',
                          body: 'Keep messages focused on studying.',
                        ),
                      for (final message in visibleMessages)
                        GestureDetector(
                          onLongPress: () => _messageActions(app, message),
                          child: Align(
                            alignment: message.isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 9),
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: message.isMine
                                    ? context.appBrandPanel
                                    : context.appSurface,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (message.isPinned)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AppIcon(
                                            Icons.push_pin_rounded,
                                            size: 12,
                                            color: message.isMine
                                                ? context.appAccentMuted
                                                : AppColors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'PINNED',
                                            style: TextStyle(
                                              color: message.isMine
                                                  ? context.appAccentMuted
                                                  : AppColors.red,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: .8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (message.replyBody != null)
                                    Text(
                                      '↳ ${message.replyBody}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: message.isMine
                                            ? Colors.white70
                                            : context.appMuted,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  _messageBody(context, message),
                                  if (message.reactions.isNotEmpty)
                                    Text(
                                      message.reactions.join('  '),
                                      style: TextStyle(
                                        color: message.isMine
                                            ? Colors.white70
                                            : context.appMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (replyId != null)
            PremiumListRow(
              dense: true,
              title: const Text('Replying to a message'),
              trailing: IconButton(
                onPressed: () => setState(() => replyId = null),
                icon: const AppIcon(Icons.close_rounded),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: _showMentionSuggestion
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _insertMention,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: context.appRaisedSurface,
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(color: context.appLine),
                                ),
                                child: Row(
                                  children: [
                                    AppIcon(
                                      Icons.alternate_email_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '@$_mentionHandle',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            'Mention the person in this chat',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: context.appMuted,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const AppIcon(Icons.north_west_rounded),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          onChanged: _onDraftChanged,
                          decoration: const InputDecoration(
                            hintText: 'Write a kind, useful note',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () async {
                          final body = input.text.trim();
                          if (body.isEmpty) return;
                          await app.sendDirectMessage(
                            widget.conversationId,
                            body,
                            replyTo: replyId,
                          );
                          input.clear();
                          setState(() {
                            replyId = null;
                            _showMentionSuggestion = false;
                          });
                          await _load();
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.red,
                        ),
                        icon: const AppIcon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
