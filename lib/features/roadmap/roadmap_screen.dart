import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/ui.dart';
import '../app/app_controller.dart';
import 'ai_tools_screen.dart';

const _timeWindows = <String, String>{
  'weekday_morning': 'Weekday mornings',
  'weekday_afternoon': 'Weekday afternoons',
  'weekday_evening': 'Weekday evenings',
  'weekend_morning': 'Weekend mornings',
  'weekend_afternoon': 'Weekend afternoons',
  'weekend_evening': 'Weekend evenings',
};

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key, this.initialSection = 0});
  final int initialSection;
  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  late int _section = widget.initialSection;
  bool _loaded = false;
  bool _matchingEnabled = false;
  final _subjects = TextEditingController();
  final _courses = TextEditingController();
  final _leaderboardName = TextEditingController();
  final _friendName = TextEditingController();
  final _schoolEmail = TextEditingController();
  final _institutionName = TextEditingController();
  final _institutionDomain = TextEditingController();
  final Set<String> _availability = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final app = context.read<AppController>();
    unawaited(
      Future.wait([
        app.loadMatching(),
        app.loadFriends(),
        app.loadProgress(),
        app.loadCommunities(),
      ]).then((_) {
        if (!mounted) return;
        final prefs = app.matchingPreferences;
        _subjects.text = ((prefs['subjects'] as List?) ?? const []).join(', ');
        _courses.text = ((prefs['courses'] as List?) ?? const []).join(', ');
        _matchingEnabled = prefs['enabled'] == true;
        _availability.addAll(
          ((prefs['availability'] as List?) ?? const []).map((x) => '$x'),
        );
        _leaderboardName.text =
            '${app.leaderboardSettings['display_name'] ?? app.displayName}';
        setState(() {});
      }),
    );
  }

  @override
  void dispose() {
    _subjects.dispose();
    _courses.dispose();
    _leaderboardName.dispose();
    _friendName.dispose();
    _schoolEmail.dispose();
    _institutionName.dispose();
    _institutionDomain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) => Scaffold(
      backgroundColor: context.appPaper,
      body: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            BrandRefreshSliver(
              onRefresh: () async => Future.wait([
                app.loadMatching(),
                app.loadFriends(),
                app.loadProgress(),
                app.loadCommunities(),
              ]),
            ),
            BrandGlassSliverBar(
              actions: [
                IconButton(
                  tooltip: 'AI study tools',
                  onPressed: () => Navigator.push(
                    context,
                    aLaStudieRoute(
                      context: context,
                      builder: (_) => const AiToolsScreen(),
                    ),
                  ),
                  icon: const AppIcon(Icons.auto_awesome_outlined, size: 19),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(19, 12, 19, 28),
              sliver: SliverList.list(
                children: [
                  const Eyebrow('YOUR NEXT STUDY CHAPTER'),
                  const SizedBox(height: 4),
                  Text(
                    'Find your people.',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 13),
                  _SectionPicker(
                    selected: _section,
                    onSelect: (value) => setState(() => _section = value),
                  ),
                  const SizedBox(height: 15),
                  switch (_section) {
                    0 => _matchingView(context, app),
                    1 => _friendsView(context, app),
                    2 => _progressView(context, app),
                    _ => _communitiesView(context, app),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _matchingView(BuildContext context, AppController app) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SoftPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('ONLY IF YOU WANT IT'),
            const SizedBox(height: 3),
            const Text(
              'Match on your terms',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              'Recommendations use the subjects, courses and broad time windows you choose. Your school and exact availability stay private.',
              style: TextStyle(
                color: context.appMuted,
                height: 1.35,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _ToggleRow(
              label: 'Show me study partner recommendations',
              value: _matchingEnabled,
              onChanged: (value) => setState(() => _matchingEnabled = value),
            ),
            TextField(
              controller: _subjects,
              decoration: const InputDecoration(
                labelText: 'Subjects',
                hintText: 'e.g. biology, statistics',
              ),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: _courses,
              decoration: const InputDecoration(
                labelText: 'Courses',
                hintText: 'e.g. BIO 201',
              ),
            ),
            const SizedBox(height: 12),
            const Eyebrow('BROAD STUDY WINDOWS'),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final entry in _timeWindows.entries)
                  _Pill(
                    label: entry.value,
                    selected: _availability.contains(entry.key),
                    onTap: () => setState(
                      () => _availability.contains(entry.key)
                          ? _availability.remove(entry.key)
                          : _availability.add(entry.key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 13),
            PrimaryAction(
              label: _matchingEnabled
                  ? 'Save matching preferences'
                  : 'Keep recommendations off',
              icon: Icons.tune_rounded,
              onPressed: () async {
                await app.saveMatchingPreferences(
                  enabled: _matchingEnabled,
                  subjects: _split(_subjects.text),
                  courses: _split(_courses.text),
                  availability: _availability.toList(),
                );
                if (context.mounted)
                  showAppMessage(
                    context,
                    app.errorMessage ?? 'Your matching choices are saved.',
                  );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const SectionHeading('Rooms that fit your study'),
      const SizedBox(height: 8),
      if (!_matchingEnabled)
        const EmptyNotice(
          title: 'Recommendations are off',
          body:
              'Turn matching on above when you want to see relevant public rooms and opt-in students.',
          icon: Icons.people_outline_rounded,
        )
      else if (app.recommendedRooms.isEmpty)
        const EmptyNotice(
          title: 'No close room matches yet',
          body:
              'Try another subject or course, or check Discover for every public room.',
          icon: Icons.meeting_room_outlined,
        )
      else
        for (final row in app.recommendedRooms)
          _RecommendationCard(
            title: '${row['title'] ?? 'Study room'}',
            subtitle:
                '${row['subject'] ?? 'Study'}${'${row['course'] ?? ''}'.isNotEmpty ? ' · ${row['course']}' : ''}',
            detail:
                '${row['member_count'] ?? 0} students · ${row['host_name'] ?? 'Host'}',
            icon: Icons.meeting_room_outlined,
            action: 'Open room',
            onTap: () =>
                app.joinRoom(StudyRoom.fromJson(row.cast<String, dynamic>())),
          ),
      const SizedBox(height: 15),
      const SectionHeading('Students who opted in'),
      const SizedBox(height: 8),
      if (!_matchingEnabled)
        const SizedBox.shrink()
      else if (app.recommendedPeople.isEmpty)
        Text(
          'More people appear as they opt in to matching.',
          style: TextStyle(color: context.appMuted),
        )
      else
        for (final person in app.recommendedPeople)
          _RecommendationCard(
            title:
                '${person['displayName'] ?? person['username'] ?? 'Student'}',
            subtitle: [
              ...((person['sharedSubjects'] as List?) ?? const []).map(
                (x) => '$x',
              ),
              ...((person['sharedCourses'] as List?) ?? const []).map(
                (x) => '$x',
              ),
            ].join(' · '),
            detail: person['similarStudyWindows'] == true
                ? 'Similar broad study windows'
                : 'A shared study interest',
            icon: Icons.person_outline_rounded,
            action: 'Request a chat',
            onTap: () async {
              await app.requestDirectMessage('${person['username']}');
              if (context.mounted)
                showAppMessage(
                  context,
                  app.errorMessage ?? 'Message request sent.',
                );
            },
          ),
    ],
  );

  Widget _friendsView(BuildContext context, AppController app) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SoftPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('STUDY CONNECTIONS'),
            const SizedBox(height: 4),
            const Text(
              'Keep your circle close',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 9),
            TextField(
              controller: _friendName,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                suffixIcon: IconButton(
                  onPressed: () async {
                    final name = _friendName.text.trim();
                    if (name.isEmpty) return;
                    await app.requestFriend(name);
                    _friendName.clear();
                    if (context.mounted)
                      showAppMessage(
                        context,
                        app.errorMessage ?? 'Connection request sent.',
                      );
                  },
                  icon: const AppIcon(Icons.person_add_alt_1_rounded, size: 17),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 17),
      const SectionHeading('Requests'),
      const SizedBox(height: 8),
      if (app.friendRequests.isEmpty)
        Text(
          'No pending friend requests.',
          style: TextStyle(color: context.appMuted),
        ),
      for (final request in app.friendRequests)
        _FriendRequestCard(
          request: request,
          currentUserId: app.currentUser?.id ?? '',
        ),
      const SizedBox(height: 12),
      SectionHeading('Friends · ${app.friends.length}'),
      const SizedBox(height: 8),
      if (app.friends.isEmpty)
        const EmptyNotice(
          title: 'Your study circle starts here',
          body:
              'Accepted connections are separate from private-message requests.',
          icon: Icons.groups_outlined,
        ),
      for (final friend in app.friends)
        _RecommendationCard(
          title: '${friend['displayName'] ?? friend['username']}',
          subtitle: '@${friend['username']}',
          detail: '',
          icon: Icons.person_rounded,
          action: 'Remove',
          onTap: () => app.removeFriend('${friend['id']}'),
        ),
    ],
  );

  Widget _progressView(BuildContext context, AppController app) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SoftPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('PRIVATE BY DEFAULT'),
            const SizedBox(height: 4),
            const Text(
              'Progress you can keep',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'ACHIEVEMENTS',
                    value:
                        '${app.achievements.isEmpty ? 0 : app.achievements.where((x) => x['unlocked_at'] != null).length} badges',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'FOCUS TIME',
                    value: _hoursLabel(
                      int.tryParse(
                            '${app.stats['focusedSeconds30Days'] ?? 0}',
                          ) ??
                          0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ToggleRow(
              label: 'Join the public weekly leaderboard',
              value: app.leaderboardSettings['enabled'] == true,
              onChanged: (value) async {
                await app.setLeaderboard(
                  enabled: value,
                  displayName: _leaderboardName.text.trim().isEmpty
                      ? app.displayName
                      : _leaderboardName.text.trim(),
                );
              },
            ),
            TextField(
              controller: _leaderboardName,
              maxLength: 32,
              decoration: const InputDecoration(
                labelText: 'Leaderboard display name',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only this name and your completed focus-session score for this week appear. Participation is optional.',
              style: TextStyle(
                color: context.appMuted,
                fontSize: 11,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 11),
            PrimaryAction(
              label: 'Save leaderboard choice',
              icon: Icons.leaderboard_outlined,
              onPressed: () => app.setLeaderboard(
                enabled: app.leaderboardSettings['enabled'] == true,
                displayName: _leaderboardName.text.trim(),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 17),
      const SectionHeading('Achievements'),
      const SizedBox(height: 7),
      if (app.achievements.isEmpty)
        const EmptyNotice(
          title: 'Your first win is waiting',
          body:
              'Finish focused sessions or check in to room meetings to build your private study history.',
          icon: Icons.emoji_events_outlined,
        ),
      for (final badge in app.achievements) _AchievementRow(badge: badge),
      const SizedBox(height: 16),
      const SectionHeading('This week · opt-in leaderboard'),
      const SizedBox(height: 8),
      if (app.leaderboardSettings['enabled'] != true)
        const EmptyNotice(
          title: 'You are not listed',
          body:
              'Turn on public leaderboard participation above if you want to join.',
          icon: Icons.leaderboard_outlined,
        )
      else if (app.weeklyLeaderboard.isEmpty)
        Text(
          'No sessions recorded for the current week yet.',
          style: TextStyle(color: context.appMuted),
        )
      else
        for (final entry in app.weeklyLeaderboard)
          _RecommendationCard(
            title: '#${entry['rank']}  ${entry['displayName']}',
            subtitle: '${entry['weeklyScore']} focused sessions',
            detail: '',
            icon: Icons.leaderboard_outlined,
            action: '',
            onTap: null,
          ),
    ],
  );

  Widget _communitiesView(BuildContext context, AppController app) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SoftPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('CAMPUS, WHEN YOU WANT IT'),
            const SizedBox(height: 4),
            const Text(
              'Study with your university',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'School verification is separate from your login email. If a school domain is unsupported, a verified member can invite you.',
              style: TextStyle(
                color: context.appMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _schoolEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Optional school email',
              ),
            ),
            const SizedBox(height: 9),
            PrimaryAction(
              label: 'Send verification code',
              icon: Icons.mark_email_read_outlined,
              onPressed: () async {
                await app.requestSchoolEmail(_schoolEmail.text.trim());
                if (context.mounted && app.errorMessage == null)
                  _verifySchoolCode(context, app);
                if (context.mounted && app.errorMessage != null)
                  showAppMessage(context, app.errorMessage);
              },
            ),
          ],
        ),
      ),
      if (app.currentUser?.isAdmin == true) ...[
        const SizedBox(height: 11),
        SoftPanel(
          child: Column(
            children: [
              const Eyebrow('ADMIN · DOMAIN DIRECTORY'),
              TextField(
                controller: _institutionName,
                decoration: const InputDecoration(labelText: 'University name'),
              ),
              TextField(
                controller: _institutionDomain,
                decoration: const InputDecoration(
                  labelText: 'Verified email domain',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await app.createInstitution(
                    _institutionName.text.trim(),
                    _institutionDomain.text.trim(),
                  );
                  if (context.mounted) {
                    showAppMessage(
                      context,
                      app.errorMessage ?? 'University domain added.',
                    );
                  }
                },
                child: const Text('Add domain'),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      const SectionHeading('University communities'),
      const SizedBox(height: 8),
      if (app.communities.isEmpty)
        const EmptyNotice(
          title: 'No community directory yet',
          body:
              'University domains are added by an administrator before school email verification can begin.',
          icon: Icons.school_outlined,
        ),
      for (final community in app.communities)
        _RecommendationCard(
          title:
              '${community['name'] ?? community['institution_name'] ?? 'Campus community'}',
          subtitle:
              '${community['institution_name'] ?? ''} · ${community['member_count'] ?? 0} members',
          detail: community['verification_method'] == 'member_invite'
              ? 'Invite-verified membership'
              : community['verification_method'] == 'school_email'
              ? 'School email verified'
              : 'Verify your school email or accept an invite',
          icon: Icons.school_outlined,
          action:
              community['verification_method'] == null ||
                  community['invite_id'] != null
              ? (community['invite_id'] != null ? 'Accept invite' : 'Join')
              : 'Invite student',
          onTap: () async {
            if (community['verification_method'] == null ||
                community['invite_id'] != null) {
              await app.joinCommunity('${community['id']}');
            } else {
              final username = await _askText(
                context,
                'Invite a student',
                'Username',
              );
              if (username != null)
                await app.inviteCommunityMember('${community['id']}', username);
            }
          },
        ),
    ],
  );

  Future<void> _verifySchoolCode(
    BuildContext context,
    AppController app,
  ) async {
    final code = await _askText(
      context,
      'Enter school email code',
      'Verification code',
    );
    if (code == null) return;
    await app.verifySchoolEmail(_schoolEmail.text.trim(), code);
    if (context.mounted)
      showAppMessage(context, app.errorMessage ?? 'School email verified.');
  }
}

class _SectionPicker extends StatelessWidget {
  const _SectionPicker({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: _Pill(
              label: const ['MATCH', 'FRIENDS', 'PROGRESS', 'CAMPUS'][i],
              selected: selected == i,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.red : context.appSurface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: selected ? AppColors.red : context.appLine),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : context.appInk,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .4,
        ),
      ),
    ),
  );
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.icon,
    required this.action,
    required this.onTap,
  });
  final String title, subtitle, detail, action;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SoftPanel(
      color: context.appSurface,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: context.appBrandPanel,
              borderRadius: BorderRadius.circular(13),
            ),
            child: AppIcon(icon, size: 17, color: context.appBrandInk),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.appMuted, fontSize: 11),
                  ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.appMuted, fontSize: 10),
                  ),
              ],
            ),
          ),
          if (action.isNotEmpty)
            TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animationDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
        Semantics(
          label: label,
          toggled: value,
          onTap: () => onChanged(!value),
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!value),
              child: SizedBox(
                width: 48,
                height: 44,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedContainer(
                    duration: animationDuration,
                    curve: Curves.easeOutCubic,
                    width: 40,
                    height: 24,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: value ? AppColors.red : context.appLine,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: value ? AppColors.red : context.appMuted,
                      ),
                    ),
                    child: AnimatedAlign(
                      duration: animationDuration,
                      curve: Curves.easeOutCubic,
                      alignment: value
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: context.appMuted,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
      ),
    ],
  );
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.badge});
  final JsonMap badge;
  @override
  Widget build(BuildContext context) {
    final unlocked = badge['unlocked_at'] != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: SoftPanel(
        color: context.appSurface,
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            AppIcon(
              unlocked
                  ? Icons.emoji_events_rounded
                  : Icons.lock_outline_rounded,
              size: 18,
              color: unlocked ? AppColors.red : context.appMuted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${badge['title']}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${badge['description']}',
                    style: TextStyle(color: context.appMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (unlocked) const Eyebrow('EARNED'),
          ],
        ),
      ),
    );
  }
}

class _FriendRequestCard extends StatelessWidget {
  const _FriendRequestCard({
    required this.request,
    required this.currentUserId,
  });
  final JsonMap request;
  final String currentUserId;
  @override
  Widget build(BuildContext context) {
    final incoming = request['recipient_id'] == currentUserId;
    final app = context.read<AppController>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftPanel(
        color: context.appSurface,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: context.appBrandPanel,
                borderRadius: BorderRadius.circular(13),
              ),
              child: AppIcon(
                Icons.person_add_alt_1_rounded,
                size: 17,
                color: context.appBrandInk,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incoming
                        ? '@${request['sender_username'] ?? 'Student'}'
                        : '@${request['recipient_username'] ?? 'Student'}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    incoming ? 'Wants to connect with you' : 'Request sent',
                    style: TextStyle(color: context.appMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (incoming) ...[
              TextButton(
                onPressed: () => app.respondToFriendRequest(
                  '${request['id']}',
                  accept: false,
                ),
                child: const Text('Decline'),
              ),
              FilledButton(
                onPressed: () => app.respondToFriendRequest(
                  '${request['id']}',
                  accept: true,
                ),
                child: const Text('Accept'),
              ),
            ] else
              Text(
                'Pending',
                style: TextStyle(color: context.appMuted, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

List<String> _split(String value) => value
    .split(RegExp(r'[,·]'))
    .map((x) => x.trim())
    .where((x) => x.isNotEmpty)
    .toList();
String _hoursLabel(int seconds) =>
    '${(seconds / 3600).floor()}h ${(seconds % 3600 ~/ 60)}m';

Future<String?> _askText(
  BuildContext context,
  String title,
  String hint,
) async {
  final controller = TextEditingController();
  final value = await showPremiumBottomSheet<String>(
    context: context,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(title.toUpperCase()),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: hint),
          ),
          const SizedBox(height: 11),
          PrimaryAction(
            label: 'Continue',
            onPressed: () =>
                Navigator.pop(sheetContext, controller.text.trim()),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return value?.isEmpty == true ? null : value;
}
