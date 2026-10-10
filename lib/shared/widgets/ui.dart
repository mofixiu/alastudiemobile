import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.45,
      color: color ?? context.appMuted,
    ),
  );
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.color, this.fontSize = 20});

  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.primary;
    final style = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -.55,
      color: foreground,
    );

    final iGlyph = TextPainter(
      text: TextSpan(text: 'ı', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = iGlyph.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );

    return Semantics(
      label: 'aLaStudie',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            style: style,
            children: [
              const TextSpan(text: 'aLaStud'),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Baseline(
                  baseline: baseline,
                  baselineType: TextBaseline.alphabetic,
                  child: SizedBox(
                    width: iGlyph.width,
                    height: iGlyph.height,
                    child: CustomPaint(
                      painter: _BrandWordmarkIPainter(
                        glyph: iGlyph,
                        fontSize: fontSize,
                      ),
                    ),
                  ),
                ),
              ),
              const TextSpan(text: 'e'),
            ],
          ),
        ),
      ),
    );
  }
}

class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.initial,
    required this.size,
    required this.backgroundColor,
    this.foregroundColor,
    this.fontSize,
  });

  final String initial;
  final double size;
  final Color backgroundColor;
  final Color? foregroundColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
    child: Text(
      initial.isEmpty ? '?' : initial.characters.first.toUpperCase(),
      style: TextStyle(
        color: foregroundColor ?? context.appInk,
        fontWeight: FontWeight.w900,
        fontSize: fontSize ?? size * .42,
      ),
    ),
  );
}

class BrandGlassSliverBar extends StatelessWidget {
  const BrandGlassSliverBar({
    super.key,
    this.leading,
    this.actions = const [],
    this.wordmarkSize = 21,
  });

  final Widget? leading;
  final List<Widget> actions;
  final double wordmarkSize;

  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
    pinned: true,
    delegate: _BrandGlassHeaderDelegate(
      leading: leading,
      actions: actions,
      wordmarkSize: wordmarkSize,
      topInset: MediaQuery.paddingOf(context).top,
    ),
  );
}

/// Pull-to-refresh that draws the aLaStudie ribbon instead of a stock spinner.
/// Place it as the first sliver in a bouncing CustomScrollView.
class BrandRefreshSliver extends StatelessWidget {
  const BrandRefreshSliver({super.key, required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => CupertinoSliverRefreshControl(
    onRefresh: _performRefresh,
    // The pull mark used to sit under the Dynamic Island. Reserve just enough
    // of the pulled extent for the iOS status safe area, without adding a
    // permanent spacer to the page's top edge. Keep the pull distance close to
    // the familiar iOS threshold so refresh still feels easy to trigger.
    refreshTriggerPullDistance: _triggerDistance(context),
    refreshIndicatorExtent: MediaQuery.paddingOf(context).top + 36,
    builder:
        (
          context,
          mode,
          pulledExtent,
          refreshTriggerPullDistance,
          refreshIndicatorExtent,
        ) => _BrandRefreshMark(
          mode: mode,
          pulledExtent: pulledExtent,
          safeTopInset: MediaQuery.paddingOf(context).top,
          progress:
              ((pulledExtent - MediaQuery.paddingOf(context).top) /
                      (_triggerDistance(context) -
                          MediaQuery.paddingOf(context).top))
                  .clamp(0, 1)
                  .toDouble(),
        ),
  );

  double _triggerDistance(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeAwareDistance = safeTop + 44;
    return safeAwareDistance > 100 ? safeAwareDistance : 100;
  }

  Future<void> _performRefresh() async {
    final elapsed = Stopwatch()..start();
    try {
      await onRefresh();
    } finally {
      const minimumFeedback = Duration(milliseconds: 420);
      final remaining = minimumFeedback - elapsed.elapsed;
      if (remaining.inMilliseconds > 0) await Future<void>.delayed(remaining);
    }
  }
}

class _BrandRefreshMark extends StatefulWidget {
  const _BrandRefreshMark({
    required this.mode,
    required this.pulledExtent,
    required this.safeTopInset,
    required this.progress,
  });

  final RefreshIndicatorMode mode;
  final double pulledExtent;
  final double safeTopInset;
  final double progress;

  @override
  State<_BrandRefreshMark> createState() => _BrandRefreshMarkState();
}

class _BrandRefreshMarkState extends State<_BrandRefreshMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSweep();
  }

  @override
  void didUpdateWidget(covariant _BrandRefreshMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _syncSweep();
  }

  void _syncSweep() {
    if (widget.mode == RefreshIndicatorMode.refresh &&
        !MediaQuery.disableAnimationsOf(context)) {
      _sweep.repeat();
    } else {
      _sweep.stop();
      _sweep.value = 0;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final armed = widget.mode == RefreshIndicatorMode.armed;
    final refreshing = widget.mode == RefreshIndicatorMode.refresh;

    final markTop = (widget.pulledExtent - 36)
        .clamp(0.0, widget.safeTopInset)
        .toDouble();

    return SizedBox(
      height: widget.pulledExtent,
      child: Padding(
        padding: EdgeInsets.only(top: markTop),
        child: SizedBox(
          height: 36,
          child: Center(
            child: AnimatedBuilder(
              animation: _sweep,
              builder: (context, _) => CustomPaint(
                size: const Size(54, 28),
                painter: _BrandRefreshRibbonPainter(
                  ink: context.appInk,
                  red: AppColors.red,
                  progress: widget.progress,
                  phase: refreshing ? _sweep.value : null,
                  armed: armed,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandRefreshRibbonPainter extends CustomPainter {
  const _BrandRefreshRibbonPainter({
    required this.ink,
    required this.red,
    required this.progress,
    required this.phase,
    required this.armed,
  });

  final Color ink;
  final Color red;
  final double progress;
  final double? phase;
  final bool armed;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(3, size.height * .72)
      ..cubicTo(
        size.width * .25,
        size.height * -.05,
        size.width * .34,
        size.height * 1.05,
        size.width * .56,
        size.height * .53,
      )
      ..cubicTo(
        size.width * .74,
        size.height * .08,
        size.width * .78,
        size.height * 1.02,
        size.width - 3,
        size.height * .28,
      );
    final metric = path.computeMetrics().first;
    final track = Paint()
      ..color = ink.withValues(alpha: .2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, track);

    double beadDistance;
    if (phase != null) {
      beadDistance = metric.length * phase!;
      final trailLength = metric.length * .34;
      final start = beadDistance - trailLength;
      if (start >= 0) {
        canvas.drawPath(metric.extractPath(start, beadDistance), active);
      } else {
        canvas.drawPath(metric.extractPath(0, beadDistance), active);
        canvas.drawPath(
          metric.extractPath(metric.length + start, metric.length),
          active,
        );
      }
    } else {
      final amount = armed ? 1.0 : progress.clamp(0, 1);
      beadDistance = metric.length * amount;
      if (beadDistance > 0) {
        canvas.drawPath(metric.extractPath(0, beadDistance), active);
      }
    }

    final point = metric
        .getTangentForOffset(beadDistance.clamp(0, metric.length))
        ?.position;
    if (point != null) {
      canvas.drawCircle(point, 3, Paint()..color = red);
    }
  }

  @override
  bool shouldRepaint(_BrandRefreshRibbonPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.phase != phase ||
      oldDelegate.armed != armed ||
      oldDelegate.ink != ink ||
      oldDelegate.red != red;
}

class BrandRouteHeader extends StatelessWidget implements PreferredSizeWidget {
  const BrandRouteHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.actions = const [],
  });

  final String eyebrow;
  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(86);

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
      child: Container(
        decoration: BoxDecoration(
          color: context.appPaper.withValues(alpha: .86),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const AppIcon(Icons.arrow_back_rounded),
                    ),
                    const BrandWordmark(fontSize: 16),
                    const Spacer(),
                    ...actions,
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 9),
                  child: Row(
                    children: [
                      Eyebrow(eyebrow),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
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
    ),
  );
}

class _BrandGlassHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _BrandGlassHeaderDelegate({
    required this.leading,
    required this.actions,
    required this.wordmarkSize,
    required this.topInset,
  });

  final Widget? leading;
  final List<Widget> actions;
  final double wordmarkSize;
  final double topInset;
  static const _barHeight = 62.0;

  @override
  double get minExtent => topInset + _barHeight;

  @override
  double get maxExtent => topInset + _barHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: context.appPaper.withValues(alpha: .64)),
            if (topInset > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topInset,
                child: ColoredBox(
                  color: context.appPaper.withValues(alpha: .18),
                ),
              ),
            Positioned(
              top: topInset,
              left: 0,
              right: 0,
              height: _barHeight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: context.appPaper.withValues(alpha: .18),
                ),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 10),
                    ],
                    BrandWordmark(fontSize: wordmarkSize),
                    const Spacer(),
                    ...actions,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.appPaper.withValues(alpha: .08),
                      context.appPaper.withValues(alpha: .42),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  bool shouldRebuild(_BrandGlassHeaderDelegate oldDelegate) =>
      leading != oldDelegate.leading ||
      actions != oldDelegate.actions ||
      wordmarkSize != oldDelegate.wordmarkSize ||
      topInset != oldDelegate.topInset;
}

class _BrandWordmarkIPainter extends CustomPainter {
  const _BrandWordmarkIPainter({required this.glyph, required this.fontSize});

  final TextPainter glyph;
  final double fontSize;

  @override
  void paint(Canvas canvas, Size size) {
    glyph.paint(canvas, Offset.zero);
    canvas.drawCircle(
      Offset(size.width / 2, fontSize * .2),
      fontSize * .075,
      Paint()..color = AppColors.red,
    );
  }

  @override
  bool shouldRepaint(_BrandWordmarkIPainter oldDelegate) =>
      oldDelegate.fontSize != fontSize || oldDelegate.glyph.text != glyph.text;
}

class BrandFeaturePanel extends StatefulWidget {
  const BrandFeaturePanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    this.actionIcon = Icons.arrow_outward_rounded,
    this.titleSize = 32,
    this.titleWidthFactor = .7,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData actionIcon;
  final double titleSize;
  final double titleWidthFactor;

  @override
  State<BrandFeaturePanel> createState() => _BrandFeaturePanelState();
}

class _BrandFeaturePanelState extends State<BrandFeaturePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  late final Animation<double> _settle;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _settle = CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion
        ..stop()
        ..value = 1;
    } else if (_motion.status == AnimationStatus.dismissed) {
      _motion.forward();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(22, 21, 18, 19),
    decoration: BoxDecoration(
      color: context.appBrandPanel,
      borderRadius: BorderRadius.circular(28),
      boxShadow: context.appIsDark
          ? const []
          : const [
              BoxShadow(
                color: Color(0x22073F56),
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
            ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned(
            right: -6,
            top: 0,
            child: SizedBox(
              width: 116,
              height: 140,
              child: AnimatedBuilder(
                animation: _settle,
                builder: (context, _) {
                  final progress = _settle.value;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: 0,
                        top: 17,
                        child: Transform.translate(
                          offset: Offset(
                            10 * (1 - progress),
                            6 * (1 - progress),
                          ),
                          child: Transform.rotate(
                            angle: -.09 + (.21 * progress),
                            child: Container(
                              width: 91,
                              height: 110,
                              decoration: BoxDecoration(
                                color: AppColors.red,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x449A1022),
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _BrandOrbitPainter(
                            progress: progress,
                            color: context.appAccentMuted,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(widget.eyebrow, color: context.appAccentMuted),
              const SizedBox(height: 12),
              SizedBox(
                width: constraints.maxWidth * widget.titleWidthFactor,
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.titleSize,
                    height: .98,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.45,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                width: constraints.maxWidth * widget.titleWidthFactor,
                child: Text(
                  widget.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .76),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 17),
              SizedBox(
                width: 194,
                child: PrimaryAction(
                  label: widget.actionLabel,
                  icon: widget.actionIcon,
                  onPressed: widget.onAction,
                  height: 48,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _BrandOrbitPainter extends CustomPainter {
  const _BrandOrbitPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .04, size.height * .82)
      ..cubicTo(
        size.width * .05,
        size.height * .20,
        size.width * .78,
        size.height * .03,
        size.width * .96,
        size.height * .32,
      );
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final point = metric
        .getTangentForOffset(metric.length * progress)
        ?.position;
    if (point != null) {
      canvas.drawCircle(point, 3, Paint()..color = AppColors.white);
    }
  }

  @override
  bool shouldRepaint(_BrandOrbitPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class OneShotReveal extends StatefulWidget {
  const OneShotReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.distance = 12,
  });

  final Widget child;
  final int index;
  final double distance;

  @override
  State<OneShotReveal> createState() => _OneShotRevealState();
}

class _OneShotRevealState extends State<OneShotReveal>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  Timer? _stagger;
  bool _started = false;

  @override
  bool get wantKeepAlive => widget.index <= 6;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.index > 6 || MediaQuery.disableAnimationsOf(context)) {
      _stagger?.cancel();
      _started = true;
      _controller
        ..stop()
        ..value = 1;
    } else if (!_started) {
      _started = true;
      final delay = (widget.index.clamp(0, 6) * 48).toInt();
      if (delay == 0) {
        _controller.forward();
      } else {
        _stagger = Timer(Duration(milliseconds: delay), () {
          if (mounted) _controller.forward();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant OneShotReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) updateKeepAlive();
  }

  @override
  void dispose() {
    _stagger?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _progress.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _progress.value) * widget.distance),
          child: child,
        ),
      ),
    );
  }
}

Future<T?> showBrandedBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    enableDrag: true,
    isDismissible: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x9907131A),
    sheetAnimationStyle: reduceMotion
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 440),
            reverseDuration: Duration(milliseconds: 280),
          ),
    builder: builder,
  );
}

Future<T?> showPremiumBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxHeightFactor = .88,
  bool isScrollControlled = true,
}) => showBrandedBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  builder: (sheetContext) => PremiumSheetSurface(
    maxHeightFactor: maxHeightFactor,
    child: builder(sheetContext),
  ),
);

Future<DateTime?> showBrandedDateTimePicker({
  required BuildContext context,
  required DateTime initialDateTime,
  required DateTime minimumDate,
  required DateTime maximumDate,
  String eyebrow = 'PICK A TIME',
  String title = 'Choose a start',
  String confirmLabel = 'Use this time',
}) => showPremiumBottomSheet<DateTime>(
  context: context,
  maxHeightFactor: .72,
  builder: (_) => _BrandedDateTimePicker(
    initialDateTime: initialDateTime,
    minimumDate: minimumDate,
    maximumDate: maximumDate,
    eyebrow: eyebrow,
    title: title,
    confirmLabel: confirmLabel,
  ),
);

DateTime alignDateTimeToMinuteInterval({
  required DateTime value,
  required DateTime minimum,
  required DateTime maximum,
  int interval = 5,
}) {
  DateTime roundedUp(DateTime date) {
    final minute = DateTime(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
    );
    final remainder = minute.minute % interval;
    return remainder == 0
        ? minute
        : minute.add(Duration(minutes: interval - remainder));
  }

  DateTime roundedDown(DateTime date) => DateTime(
    date.year,
    date.month,
    date.day,
    date.hour,
    date.minute - (date.minute % interval),
  );

  final earliest = roundedUp(minimum);
  final latest = roundedDown(maximum);
  if (earliest.isAfter(latest)) return earliest;
  final candidate = roundedUp(value.isBefore(minimum) ? minimum : value);
  if (candidate.isAfter(latest)) return latest;
  return candidate;
}

class _BrandedDateTimePicker extends StatefulWidget {
  const _BrandedDateTimePicker({
    required this.initialDateTime,
    required this.minimumDate,
    required this.maximumDate,
    required this.eyebrow,
    required this.title,
    required this.confirmLabel,
  });

  final DateTime initialDateTime;
  final DateTime minimumDate;
  final DateTime maximumDate;
  final String eyebrow;
  final String title;
  final String confirmLabel;

  @override
  State<_BrandedDateTimePicker> createState() => _BrandedDateTimePickerState();
}

class _BrandedDateTimePickerState extends State<_BrandedDateTimePicker> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = alignDateTimeToMinuteInterval(
      value: widget.initialDateTime,
      minimum: widget.minimumDate,
      maximum: widget.maximumDate,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Eyebrow(widget.eyebrow),
      const SizedBox(height: 5),
      Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
      SizedBox(
        height: 224,
        child: CupertinoTheme(
          data: CupertinoThemeData(
            brightness: context.appIsDark ? Brightness.dark : Brightness.light,
            primaryColor: AppColors.red,
            scaffoldBackgroundColor: context.appPaper,
          ),
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.dateAndTime,
            initialDateTime: _selected,
            minimumDate: widget.minimumDate,
            maximumDate: widget.maximumDate,
            minuteInterval: 5,
            onDateTimeChanged: (value) => setState(() => _selected = value),
          ),
        ),
      ),
      PrimaryAction(
        label: widget.confirmLabel,
        icon: Icons.event_available_rounded,
        onPressed: () => Navigator.pop(context, _selected),
      ),
    ],
  );
}

Future<T?> showBrandedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x9907131A),
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 360),
    pageBuilder: (context, _, _) => SafeArea(child: builder(context)),
    transitionBuilder: (context, animation, _, child) {
      if (reduceMotion) return child;
      final settle = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .02),
            end: Offset.zero,
          ).animate(settle),
          child: ScaleTransition(
            scale: Tween<double>(begin: .975, end: 1).animate(settle),
            child: child,
          ),
        ),
      );
    },
  );
}

class PremiumSheetSurface extends StatelessWidget {
  const PremiumSheetSurface({
    super.key,
    required this.child,
    this.maxHeightFactor = .88,
  });

  final Widget child;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedPadding(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.appPaper,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(18),
            ),
            border: Border.all(color: context.appLine, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4407131A),
                blurRadius: 36,
                offset: Offset(0, -10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PremiumSheetGrip(key: ValueKey('premium-sheet-grip')),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const BrandWordmark(fontSize: 14),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).maybePop(),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: AppIcon(
                                Icons.close_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumSheetGrip extends StatefulWidget {
  const _PremiumSheetGrip({super.key});

  @override
  State<_PremiumSheetGrip> createState() => _PremiumSheetGripState();
}

class _PremiumSheetGripState extends State<_PremiumSheetGrip> {
  double _downwardDistance = 0;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Swipe down to close',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _downwardDistance = 0,
      onVerticalDragUpdate: (details) {
        _downwardDistance += details.delta.dy;
      },
      onVerticalDragEnd: (details) {
        if (_downwardDistance > 28 || (details.primaryVelocity ?? 0) > 420) {
          Navigator.of(context).maybePop();
        }
        _downwardDistance = 0;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PremiumListRow extends StatelessWidget {
  const PremiumListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.contentPadding,
    this.tileColor,
    this.shape,
    this.dense = false,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;
  final Color? tileColor;
  final ShapeBorder? shape;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final radius = shape is RoundedRectangleBorder
        ? (shape! as RoundedRectangleBorder).borderRadius.resolve(
            Directionality.of(context),
          )
        : BorderRadius.circular(16);
    final padding =
        contentPadding ??
        EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 7 : 10);

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: tileColor ?? Colors.transparent,
            borderRadius: radius,
            border: tileColor == null
                ? null
                : Border.all(color: context.appLine.withValues(alpha: .7)),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 11)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DefaultTextStyle.merge(
                      style: TextStyle(color: context.appInk),
                      child: title,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      DefaultTextStyle.merge(
                        style: TextStyle(color: context.appMuted),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumCheckboxRow extends StatelessWidget {
  const PremiumCheckboxRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 7),
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: value,
    enabled: onChanged != null,
    button: onChanged != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: contentPadding,
        child: Row(
          children: [
            _PremiumCheckMark(value: value, onChanged: onChanged),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    style: TextStyle(color: context.appInk),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    DefaultTextStyle.merge(
                      style: TextStyle(color: context.appMuted),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PremiumCheckbox extends StatelessWidget {
  const PremiumCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) =>
      _PremiumCheckMark(value: value, onChanged: onChanged);
}

class _PremiumCheckMark extends StatelessWidget {
  const _PremiumCheckMark({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final mark = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      width: 21,
      height: 21,
      decoration: BoxDecoration(
        color: value ? AppColors.red : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value ? AppColors.red : context.appMuted,
          width: 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: value
          ? const AppIcon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
    if (onChanged == null) return mark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged!(!value),
      child: Padding(padding: const EdgeInsets.all(3), child: mark),
    );
  }
}

class PremiumChoiceChip extends StatelessWidget {
  const PremiumChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedColor,
  });

  final Widget label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (selectedColor ?? context.appAccentMuted)
              : context.appSurface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? AppColors.marine : context.appLine,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: context.appInk,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          child: label,
        ),
      ),
    ),
  );
}

class PremiumDialogSurface extends StatelessWidget {
  const PremiumDialogSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: context.appPaper,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(29),
          topRight: Radius.circular(19),
          bottomLeft: Radius.circular(19),
          bottomRight: Radius.circular(29),
        ),
        border: Border.all(color: context.appLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x5507131A),
            blurRadius: 34,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandWordmark(fontSize: 14),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    ),
  );
}

PageRoute<T> aLaStudieRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  // CupertinoPageRoute provides iOS's interactive edge-swipe pop gesture.
  // Keep pushed screens on this shared route instead of PageRouteBuilder.
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return CupertinoPageRoute<T>(builder: builder);
  }
  return MaterialPageRoute<T>(builder: builder);
}

Future<String?> showRoomCodePrompt(BuildContext context) async {
  final controller = TextEditingController();
  try {
    return await showBrandedDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(22, 21, 22, 20),
            decoration: BoxDecoration(
              color: context.appPaper,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(26),
                bottomRight: Radius.circular(26),
              ),
              border: Border.all(color: context.appLine, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4407131A),
                  blurRadius: 36,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandWordmark(fontSize: 15),
                    const Spacer(),
                    Transform.rotate(
                      angle: -.12,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const AppIcon(
                          Icons.key_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 19),
                const Eyebrow('PRIVATE ROOM'),
                const SizedBox(height: 5),
                Text(
                  'Enter a room code',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  'Paste the code someone sent you.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: context.appMuted),
                ),
                const SizedBox(height: 17),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setDialogState(() {}),
                  onSubmitted: (_) {
                    if (controller.text.trim().isNotEmpty) {
                      Navigator.pop(dialogContext, controller.text.trim());
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'ROOM CODE',
                    prefixIcon: AppIcon(Icons.key_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryAction(
                  label: 'Join the room',
                  icon: Icons.arrow_outward_rounded,
                  onPressed: controller.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(
                          dialogContext,
                          controller.text.trim(),
                        ),
                ),
                const SizedBox(height: 5),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Maybe later'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          child: Text(
            action!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
    ],
  );
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.color = AppColors.red,
    this.foreground = Colors.white,
    this.height = 54,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final Color color;
  final Color foreground;
  final double height;
  @override
  Widget build(BuildContext context) {
    final enabled = !busy && onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: busy ? 'Loading: $label' : label,
        child: GestureDetector(
          onTap: enabled ? onPressed : null,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: enabled ? color : color.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox.square(
                    dimension: 18,
                    child: CupertinoActivityIndicator(color: foreground),
                  )
                else
                  AppIcon(
                    icon ?? Icons.arrow_forward_rounded,
                    size: 19,
                    color: foreground,
                  ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .1,
                    ),
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

class SoftPanel extends StatelessWidget {
  const SoftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.radius = AppRadii.large,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? context.appSurface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? context.appLine),
      boxShadow: const [
        BoxShadow(
          color: Color(0x120D2D3A),
          blurRadius: 20,
          offset: Offset(0, 9),
        ),
      ],
    ),
    child: child,
  );
}

class StatusTag extends StatelessWidget {
  const StatusTag(
    this.label, {
    super.key,
    this.color = AppColors.mint,
    this.textColor,
    this.icon,
  });
  final String label;
  final Color color;
  final Color? textColor;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final foreground =
        textColor ??
        (color == AppColors.mint || color == AppColors.lime
            ? AppColors.ink
            : context.appInk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: 13, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10,
              letterSpacing: .4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyNotice extends StatelessWidget {
  const EmptyNotice({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.auto_awesome_outlined,
    this.action,
  });
  final String title;
  final String body;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, color: Theme.of(context).colorScheme.primary, size: 32),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.appMuted),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}

class InlineErrorNotice extends StatelessWidget {
  const InlineErrorNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.red.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? .13 : .07,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.red.withValues(alpha: .32)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppIcon(
          Icons.error_outline_rounded,
          color: AppColors.red,
          size: 18,
          semanticLabel: 'Error',
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.red,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class RoomAvatarStack extends StatelessWidget {
  const RoomAvatarStack({super.key, required this.names, this.max = 4});
  final List<String> names;
  final int max;
  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    return SizedBox(
      height: 34,
      width: (shown.length * 25 + 8).toDouble(),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 23,
              child: InitialAvatar(
                size: 32,
                backgroundColor: i.isEven
                    ? context.appSoftAccent
                    : context.appSoftBlue,
                initial: shown[i],
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

void showAppMessage(BuildContext context, String? message) {
  if (message == null || message.isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
