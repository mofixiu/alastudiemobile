import 'dart:async';

import '../../shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui.dart';
import '../app/app_controller.dart';
import '../home/dashboard_screen.dart';
import '../nearby/nearby_study_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final search = TextEditingController();
  Timer? debounce;
  String filter = 'All subjects';
  final subjectFilter = TextEditingController();
  final courseFilter = TextEditingController();
  int availableSeats = 0;
  String startWindow = 'Any time';
  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    subjectFilter.dispose();
    courseFilter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) {
      final rooms = filter == 'All subjects'
          ? app.discoveryRooms
          : app.discoveryRooms
                .where(
                  (room) =>
                      room.subject.toLowerCase().contains(filter.toLowerCase()),
                )
                .toList();
      return CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          BrandRefreshSliver(onRefresh: () => _loadRooms(app)),
          const BrandGlassSliverBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrandFeaturePanel(
                    eyebrow: 'OPEN TABLES · REAL GOALS',
                    title: 'Find your\nstudy circle.',
                    description:
                        'A room for the subject or deadline in front of you.',
                    actionLabel: 'Join with code',
                    actionIcon: Icons.key_rounded,
                    onAction: () => _joinWithCode(context, app),
                    titleSize: 32,
                    titleWidthFactor: .68,
                  ),
                  const SizedBox(height: 11),
                  OneShotReveal(
                    index: 0,
                    distance: 9,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openNearby(context),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.appSurface,
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(color: context.appLine),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x10051C27),
                              blurRadius: 17,
                              offset: Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 47,
                              height: 47,
                              decoration: BoxDecoration(
                                color: context.appBrandPanel,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const AppIcon(
                                Icons.bluetooth_searching_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Eyebrow('NO INTERNET NEEDED'),
                                  SizedBox(height: 3),
                                  Text(
                                    'Study with people nearby',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const AppIcon(
                              Icons.arrow_forward_rounded,
                              color: AppColors.red,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 19),
                  TextField(
                    controller: search,
                    onChanged: (value) {
                      debounce?.cancel();
                      debounce = Timer(
                        const Duration(milliseconds: 280),
                        () => _loadRooms(app, query: value),
                      );
                    },
                    decoration: InputDecoration(
                      prefixIcon: const AppIcon(Icons.search_rounded, size: 14),
                      hintText: 'Course, subject, or goal',
                      suffixIcon: search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                search.clear();
                                _loadRooms(app, query: '');
                                setState(() {});
                              },
                              icon: const AppIcon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _openFilters(context, app),
                    icon: const AppIcon(Icons.tune_rounded),
                    label: Text(
                      _activeFilterCount == 0
                          ? 'Filters · subject, course, time, seats'
                          : 'Filters · $_activeFilterCount active',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final option in [
                          'All subjects',
                          'Computer science',
                          'Mathematics',
                          'Chemistry',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => filter = option),
                              child: AnimatedContainer(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 220),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: filter == option
                                      ? Theme.of(context).colorScheme.primary
                                      : context.appSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: filter == option
                                        ? Theme.of(context).colorScheme.primary
                                        : context.appLine,
                                  ),
                                ),
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    color: filter == option
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : context.appInk,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      const Expanded(child: SectionHeading('In the mix')),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${rooms.length} ROOMS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (app.loadingDiscovery && rooms.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 42),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LinearProgressIndicator(minHeight: 2),
                      const SizedBox(height: 14),
                      Text(
                        'Looking for your next study table…',
                        style: TextStyle(color: context.appMuted),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (rooms.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyNotice(
                title: 'No rooms match yet',
                body:
                    app.errorMessage ??
                    'Try a different subject or start a room around your own study goal.',
                icon: Icons.search_off_rounded,
                action: TextButton(
                  onPressed: () => _loadRooms(app, query: ''),
                  child: const Text('Clear search'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              sliver: SliverList.builder(
                itemCount: rooms.length,
                itemBuilder: (context, i) => OneShotReveal(
                  key: ValueKey(rooms[i].id),
                  index: i + 1,
                  distance: 14,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DiscoverRoomCard(
                      room: rooms[i],
                      featured: i.isEven,
                      onTap: () =>
                          DashboardScreen.openRoom(context, app, rooms[i]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _joinWithCode(BuildContext context, AppController app) async {
    final code = await showRoomCodePrompt(context);
    if (code == null || code.isEmpty) return;
    await app.joinRoomByCode(code);
    if (context.mounted) {
      showAppMessage(context, app.errorMessage ?? app.statusMessage);
    }
  }

  void _openNearby(BuildContext context) {
    Navigator.of(context).push<void>(
      aLaStudieRoute<void>(
        context: context,
        builder: (_) => const NearbyStudyScreen(),
      ),
    );
  }

  int get _activeFilterCount => [
    subjectFilter.text.trim().isNotEmpty,
    courseFilter.text.trim().isNotEmpty,
    startWindow != 'Any time',
    availableSeats > 0,
  ].where((active) => active).length;

  Future<void> _openFilters(BuildContext context, AppController app) async {
    await showPremiumBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('TUNE THE TABLE'),
            const SizedBox(height: 4),
            Text(
              'Find your fit.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 6),
            TextField(
              controller: subjectFilter,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g. Chemistry',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: courseFilter,
              decoration: const InputDecoration(
                labelText: 'Course',
                hintText: 'e.g. CSC 401',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Eyebrow('START TIME'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final value in ['Any time', 'Next 24 hours', 'This week'])
                  _FilterChoice(
                    label: value,
                    selected: startWindow == value,
                    onTap: () => setSheetState(() => startWindow = value),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Eyebrow('OPEN SEATS'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final count in [0, 1, 2, 4])
                  _FilterChoice(
                    label: count == 0 ? 'Any' : '$count+ seats',
                    selected: availableSeats == count,
                    onTap: () => setSheetState(() => availableSeats = count),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            PrimaryAction(
              label: 'Apply filters',
              icon: Icons.arrow_outward_rounded,
              onPressed: () {
                _loadRooms(app, query: search.text);
                setState(() {});
                Navigator.pop(context);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(36),
                padding: const EdgeInsets.symmetric(vertical: 5),
              ),
              onPressed: () {
                subjectFilter.clear();
                courseFilter.clear();
                setSheetState(() {
                  startWindow = 'Any time';
                  availableSeats = 0;
                });
                _loadRooms(app, query: search.text);
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRooms(AppController app, {String? query}) {
    final now = DateTime.now();
    final startAfter = startWindow == 'Any time' ? null : now;
    final startBefore = startWindow == 'Next 24 hours'
        ? now.add(const Duration(days: 1))
        : startWindow == 'This week'
        ? now.add(const Duration(days: 7))
        : null;
    return app.loadDiscovery(
      query: query ?? search.text,
      subject: subjectFilter.text,
      course: courseFilter.text,
      startAfter: startAfter,
      startBefore: startBefore,
      availableSeats: availableSeats,
    );
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (context.appIsDark ? const Color(0xFF222224) : AppColors.mint)
              : context.appSurface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? (context.appIsDark ? AppColors.red : AppColors.marine)
                : context.appLine,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              AppIcon(
                Icons.check_rounded,
                size: 14,
                color: context.appIsDark ? AppColors.red : AppColors.marine,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: context.appInk,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
