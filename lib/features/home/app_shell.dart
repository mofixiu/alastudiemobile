import 'dart:async';

import '../../shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui.dart';
import '../app/app_controller.dart';
import '../auth/auth_screen.dart';
import '../calendar/calendar_screen.dart';
import '../discover/discover_screen.dart';
import '../profile/profile_screen.dart';
import '../rooms/room_detail_screen.dart';
import 'dashboard_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  static const _minimumSplashDuration = Duration(milliseconds: 2400);
  Timer? _splashTimer;
  bool _minimumSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        setState(() => _minimumSplashElapsed = true);
      } else {
        _splashTimer = Timer(_minimumSplashDuration, () {
          if (mounted) setState(() => _minimumSplashElapsed = true);
        });
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final showingSplash = app.booting || !_minimumSplashElapsed;
      final Widget destination;
      final String destinationKey;
      if (showingSplash) {
        destination = const _BrandSplash();
        destinationKey = 'startup';
      } else if (!app.signedIn) {
        destination = const AuthScreen();
        destinationKey = 'authentication';
      } else if (app.activeRoomId != null) {
        destination = RoomDetailScreen(roomId: app.activeRoomId!);
        destinationKey = 'room:${app.activeRoomId}';
      } else {
        destination = const AppShell();
        destinationKey = 'home';
      }

      return AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 420),
        reverseDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: .985, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(destinationKey), child: destination),
      );
    },
  );
}

class _BrandSplash extends StatefulWidget {
  const _BrandSplash();

  @override
  State<_BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<_BrandSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late final Animation<double> _reveal;
  late final Animation<double> _settle;
  late final Animation<double> _byline;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1760),
    );
    _reveal = CurvedAnimation(
      parent: _animation,
      curve: const Interval(.08, .78, curve: Curves.easeInOutCubic),
    );
    _settle = CurvedAnimation(
      parent: _animation,
      curve: const Interval(.18, .92, curve: Curves.easeOutCubic),
    );
    _byline = CurvedAnimation(
      parent: _animation,
      curve: const Interval(.68, 1, curve: Curves.easeOut),
    );
    _animation.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _animation.value = 1;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appPaper,
    body: SafeArea(
      child: Stack(
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => CustomPaint(
                painter: _SplashTracePainter(progress: _reveal.value),
                child: SizedBox(
                  width: 300,
                  height: 100,
                  child: Center(
                    child: ClipRect(
                      clipper: _WordmarkRevealClipper(_reveal.value),
                      child: Opacity(
                        opacity: _settle.value,
                        child: Transform.translate(
                          offset: Offset(0, 9 * (1 - _settle.value)),
                          child: BrandWordmark(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: AnimatedBuilder(
              animation: _byline,
              builder: (context, child) =>
                  Opacity(opacity: _byline.value, child: child),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'CRAFTED BY  ',
                          style: TextStyle(
                            color: context.appMuted,
                            fontFamily: 'Montserrat',
                            fontSize: 9,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'mofixiu',
                          style: TextStyle(
                            color: AppColors.red,
                            fontFamily: 'Montserrat',
                            fontSize: 9,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
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

class _WordmarkRevealClipper extends CustomClipper<Rect> {
  const _WordmarkRevealClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress.clamp(0, 1), size.height);

  @override
  bool shouldReclip(_WordmarkRevealClipper oldClipper) =>
      progress != oldClipper.progress;
}

class _SplashTracePainter extends CustomPainter {
  const _SplashTracePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final trace = Path()
      ..moveTo(size.width * .13, size.height * .68)
      ..cubicTo(
        size.width * .28,
        size.height * .04,
        size.width * .72,
        size.height * .04,
        size.width * .88,
        size.height * .66,
      );
    final metric = trace.computeMetrics().first;
    final distance = metric.length * progress.clamp(0, 1);
    final paint = Paint()
      ..color = AppColors.marine.withValues(alpha: .30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(metric.extractPath(0, distance), paint);
    if (progress > .01 && progress < .99) {
      final tangent = metric.getTangentForOffset(distance);
      if (tangent != null) {
        canvas.drawCircle(
          tangent.position,
          2,
          Paint()..color = AppColors.marine.withValues(alpha: .72),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SplashTracePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});
  static const _labels = ['Home', 'Discover', 'My rooms', 'Profile'];
  static const _icons = [
    Icons.home_outlined,
    Icons.travel_explore_rounded,
    Icons.meeting_room_outlined,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final pages = [
        const DashboardScreen(),
        const DiscoverScreen(),
        const MyRoomsScreen(),
        const ProfileScreen(),
      ];
      return Scaffold(
        body: SafeArea(
          top: false,
          bottom: false,
          child: AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(app.selectedTab),
              child: pages[app.selectedTab],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            // SafeArea already accounts for the home indicator. Let the bar
            // sit close to that inset instead of floating an extra 10 px up.
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26051C27),
                  blurRadius: 24,
                  offset: Offset(0, 9),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / pages.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 380),
                      curve: Curves.easeOutQuart,
                      top: 0,
                      bottom: 0,
                      left: itemWidth * app.selectedTab,
                      width: itemWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < pages.length; i++)
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: app.selectedTab == i,
                              label: _labels[i],
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => app.setTab(i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: TweenAnimationBuilder<Color?>(
                                    tween: ColorTween(
                                      begin: app.selectedTab == i
                                          ? Colors.white
                                          : Colors.white70,
                                      end: app.selectedTab == i
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                    duration: reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, color, _) => Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AppIcon(
                                          _icons[i],
                                          color: color,
                                          size: 20,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _labels[i].toUpperCase(),
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 8,
                                            letterSpacing: .55,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class MyRoomsScreen extends StatelessWidget {
  const MyRoomsScreen({super.key});
  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) => CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        BrandRefreshSliver(onRefresh: app.loadMine),
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
              icon: const AppIcon(Icons.calendar_month_outlined, size: 20),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrandFeaturePanel(
                  eyebrow: 'YOUR STUDY TABLES',
                  title: 'Your rooms.\nYour rhythm.',
                  description: 'Spaces you host and the ones you return to.',
                  actionLabel: 'Create a room',
                  actionIcon: Icons.add_rounded,
                  onAction: () => _createRoom(context),
                  titleSize: 32,
                  titleWidthFactor: .68,
                ),
                const SizedBox(height: 20),
                if (app.myRooms.isEmpty && app.loadingMine)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Column(
                      children: [
                        const LinearProgressIndicator(minHeight: 2),
                        const SizedBox(height: 12),
                        Text(
                          'Loading your rooms…',
                          style: TextStyle(color: context.appMuted),
                        ),
                      ],
                    ),
                  )
                else if (app.myRooms.isEmpty)
                  EmptyNotice(
                    title: 'A room can become your routine',
                    body:
                        'Start with a goal, then invite people to work alongside you.',
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          sliver: SliverList.builder(
            itemCount: app.myRooms.length,
            itemBuilder: (context, i) => OneShotReveal(
              key: ValueKey(app.myRooms[i].id),
              index: i + 1,
              distance: 15,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _roomTile(context, app, app.myRooms[i]),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _roomTile(BuildContext context, AppController app, dynamic room) {
    final hosted = room.role == 'host' || room.role == 'cohost';
    final roleLabel = room.role == 'host'
        ? 'HOST'
        : room.role == 'cohost'
        ? 'CO-HOST'
        : 'MEMBER';
    final foreground = hosted ? context.appBrandInk : context.appInk;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => app.openRoom(room.id),
      child: SoftPanel(
        color: hosted ? context.appBrandPanel : context.appSurface,
        borderColor: hosted ? context.appBrandPanel : context.appLine,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Eyebrow(
                    room.subject,
                    color: hosted ? context.appAccentMuted : context.appMuted,
                  ),
                ),
                StatusTag(
                  roleLabel,
                  color: hosted
                      ? context.appSoftAccent
                      : context.appRaisedSurface,
                  textColor: hosted ? context.appInk : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              room.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              room.goal,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: hosted
                    ? Colors.white.withValues(alpha: .74)
                    : context.appMuted,
              ),
            ),
            if (room.isScheduled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  AppIcon(
                    Icons.calendar_month_outlined,
                    size: 15,
                    color: hosted ? context.appAccentMuted : context.appMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      room.scheduleSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: foreground,
                        letterSpacing: .45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 13),
            Row(
              children: [
                AppIcon(
                  Icons.groups_2_outlined,
                  size: 17,
                  color: hosted
                      ? context.appAccentMuted
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  '${room.memberCount} studying',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: foreground),
                ),
                const Spacer(),
                const AppIcon(
                  Icons.arrow_outward_rounded,
                  size: 18,
                  color: AppColors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _createRoom(BuildContext context) => showPremiumBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    maxHeightFactor: .94,
    builder: (_) => const CreateRoomSheet(),
  );
}

class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key});
  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final title = TextEditingController();
  final subject = TextEditingController();
  final course = TextEditingController();
  final goal = TextEditingController();
  String access = 'public';
  int limit = 8;
  bool scheduleLater = false;
  DateTime scheduledAt = DateTime.now().add(const Duration(hours: 1));
  String recurrence = 'none';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppController>().loadRoomTemplates();
    });
  }

  @override
  void dispose() {
    title.dispose();
    subject.dispose();
    course.dispose();
    goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Make a little space'),
        const SizedBox(height: 5),
        Text(
          'Build your room.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Consumer<AppController>(
          builder: (context, app, _) {
            if (app.loadingTemplates && app.roomTemplates.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: _SheetLoadingMark(),
              );
            }
            if (app.roomTemplates.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 7,
                children: [
                  for (final template in app.roomTemplates)
                    _SheetPill(
                      label: '${template['title']}',
                      icon: Icons.copy_all_outlined,
                      onTap: () => _applyTemplate(template),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _sheetField('ROOM NAME', title, 'e.g. CSC 401, no panic'),
        _sheetField('SUBJECT', subject, 'Computer science'),
        _sheetField('COURSE (OPTIONAL)', course, 'CSC 401'),
        _sheetField('SHARED GOAL', goal, 'Finish the first two chapters'),
        const SizedBox(height: 2),
        Consumer<AppController>(
          builder: (context, app, _) => Align(
            alignment: Alignment.centerRight,
            child: _SheetLinkAction(
              label: 'Save as template',
              icon: Icons.bookmark_add_outlined,
              onTap:
                  title.text.trim().isEmpty ||
                      subject.text.trim().isEmpty ||
                      goal.text.trim().isEmpty ||
                      app.busy
                  ? null
                  : () async {
                      await app.saveRoomTemplate(
                        title: title.text,
                        subject: subject.text,
                        course: course.text,
                        goal: goal.text,
                        accessType: access,
                        participantLimit: limit,
                        recurrence: recurrence,
                      );
                      if (context.mounted)
                        showAppMessage(
                          context,
                          app.errorMessage ?? app.statusMessage,
                        );
                    },
            ),
          ),
        ),
        const Eyebrow('WHO CAN JOIN'),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          children: [
            for (final pair in [
              ('Public', 'public'),
              ('Code / link', 'link'),
              ('Invited only', 'invite'),
            ])
              _SheetPill(
                label: pair.$1,
                selected: access == pair.$2,
                onTap: () => setState(() => access = pair.$2),
              ),
          ],
        ),
        const SizedBox(height: 15),
        const Eyebrow('WHEN SHOULD IT MEET?'),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          children: [
            _SheetPill(
              label: 'Start now',
              selected: !scheduleLater,
              onTap: () => setState(() {
                scheduleLater = false;
                recurrence = 'none';
              }),
            ),
            _SheetPill(
              label: 'Schedule',
              selected: scheduleLater,
              icon: Icons.calendar_month_outlined,
              onTap: () => setState(() => scheduleLater = true),
            ),
          ],
        ),
        if (scheduleLater) ...[
          const SizedBox(height: 8),
          _SheetDateControl(
            label: _formatSchedule(scheduledAt),
            onTap: _pickSchedule,
          ),
          const SizedBox(height: 9),
          const Eyebrow('REPEAT'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final option in [
                ('Never', 'none'),
                ('Daily', 'daily'),
                ('Weekly', 'weekly'),
              ])
                _SheetPill(
                  label: option.$1,
                  selected: recurrence == option.$2,
                  onTap: () => setState(() => recurrence = option.$2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'One room link; each occurrence starts at this local time.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.appMuted),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Eyebrow('ROOM SIZE')),
            _SheetStepButton(
              icon: Icons.remove_rounded,
              enabled: limit > 2,
              onTap: () => setState(() => limit--),
            ),
            Text('$limit', style: Theme.of(context).textTheme.titleLarge),
            _SheetStepButton(
              icon: Icons.add_rounded,
              enabled: limit < 50,
              onTap: () => setState(() => limit++),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Consumer<AppController>(
          builder: (context, app, _) => PrimaryAction(
            label: 'Create room',
            busy: app.busy,
            onPressed:
                title.text.isEmpty || subject.text.isEmpty || goal.text.isEmpty
                ? null
                : () async {
                    await app.createRoom(
                      title: title.text,
                      subject: subject.text,
                      course: course.text,
                      goal: goal.text,
                      accessType: access,
                      limit: limit,
                      scheduledAt: scheduleLater ? scheduledAt : null,
                      recurrence: scheduleLater ? recurrence : 'none',
                    );
                    if (context.mounted && app.errorMessage == null) {
                      Navigator.pop(context);
                    }
                  },
          ),
        ),
      ],
    );
  }

  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      title.text = '${template['title'] ?? ''}';
      subject.text = '${template['subject'] ?? ''}';
      course.text = '${template['course'] ?? ''}';
      goal.text = '${template['goal'] ?? ''}';
      access = '${template['access_type'] ?? 'public'}';
      limit = int.tryParse('${template['participant_limit'] ?? 8}') ?? 8;
      recurrence = '${template['recurrence'] ?? 'none'}';
      scheduleLater = recurrence != 'none';
      scheduledAt = DateTime.now().add(const Duration(hours: 1));
    });
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final selected = await showBrandedDateTimePicker(
      context: context,
      initialDateTime: scheduledAt.isBefore(now) ? now : scheduledAt,
      minimumDate: now,
      maximumDate: DateTime(now.year + 2, now.month, now.day, 23, 55),
      eyebrow: 'ROOM SCHEDULE',
      title: 'When should it meet?',
      confirmLabel: 'Set room time',
    );
    if (selected == null || !mounted) return;
    if (!selected.isAfter(DateTime.now())) {
      showAppMessage(context, 'Choose a start time in the future.');
      return;
    }
    setState(() {
      scheduledAt = selected;
    });
  }

  Widget _sheetField(
    String label,
    TextEditingController controller,
    String hint,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    ),
  );

  String _formatSchedule(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour < 12 ? 'AM' : 'PM';
    return '${months[date.month - 1]} ${date.day} · $hour:$minute $suffix';
  }
}

class _SheetPill extends StatelessWidget {
  const _SheetPill({
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.appBrandPanel : context.appRaisedSurface;
    final foreground = selected ? Colors.white : context.appInk;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : context.appLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppIcon(icon, size: 15, color: foreground),
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

class _SheetLinkAction extends StatelessWidget {
  const _SheetLinkAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 17, color: context.appBrandInk),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? context.appMuted : context.appBrandInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SheetDateControl extends StatelessWidget {
  const _SheetDateControl({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Scheduled for $label',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: context.appRaisedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appLine),
        ),
        child: Row(
          children: [
            AppIcon(Icons.calendar_month_outlined, color: context.appBrandInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            AppIcon(
              Icons.edit_calendar_outlined,
              size: 18,
              color: context.appMuted,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SheetStepButton extends StatelessWidget {
  const _SheetStepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.only(left: 5),
        decoration: BoxDecoration(
          color: context.appRaisedSurface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: context.appLine),
        ),
        alignment: Alignment.center,
        child: AppIcon(
          icon,
          size: 18,
          color: enabled ? context.appBrandInk : context.appMuted,
        ),
      ),
    ),
  );
}

class _SheetLoadingMark extends StatelessWidget {
  const _SheetLoadingMark();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: 52,
      height: 4,
      decoration: BoxDecoration(
        color: context.appBrandInk,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 9,
          decoration: BoxDecoration(
            color: AppColors.red,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    ),
  );
}
