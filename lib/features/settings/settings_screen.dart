import '../../shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui.dart';
import '../app/app_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _publicProfile;
  late bool _allowMessageRequests;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = context.read<AppController>().currentUser?.profile ?? {};
    _publicProfile = profile['visibility'] == 'public';
    _allowMessageRequests = profile['allowMessageRequests'] != false;
  }

  Future<void> _savePrivacy(
    AppController app, {
    bool? publicProfile,
    bool? allowMessageRequests,
  }) async {
    final profile = app.currentUser?.profile ?? const <String, dynamic>{};
    final nextPublic = publicProfile ?? _publicProfile;
    final nextRequests = allowMessageRequests ?? _allowMessageRequests;
    setState(() {
      _publicProfile = nextPublic;
      _allowMessageRequests = nextRequests;
    });
    await app.updateProfile(
      displayName: '${profile['displayName'] ?? ''}',
      school: '${profile['school'] ?? ''}',
      subjects: formatProfileSubjects(
        profile['subjects'],
        separator: ', ',
        emptyValue: '',
      ),
      publicProfile: nextPublic,
      allowMessageRequests: nextRequests,
    );
    if (!mounted || app.errorMessage == null) return;
    showAppMessage(context, app.errorMessage);
    final savedProfile = app.currentUser?.profile ?? const <String, dynamic>{};
    setState(() {
      _publicProfile = savedProfile['visibility'] == 'public';
      _allowMessageRequests = savedProfile['allowMessageRequests'] != false;
    });
  }

  @override
  Widget build(BuildContext context) => Consumer<AppController>(
    builder: (context, app, _) => Scaffold(
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            BrandGlassSliverBar(
              actions: [
                IconButton(
                  tooltip: 'Back to profile',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const AppIcon(Icons.close_rounded),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              sliver: SliverList.list(
                children: [
                  const Eyebrow('YOUR SPACE, YOUR RULES'),
                  const SizedBox(height: 4),
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 16),
                  BrandFeaturePanel(
                    eyebrow: 'TUNE THE FEEL',
                    title: 'Make it yours.',
                    description: 'Choose the look you want to come back to.',
                    actionLabel: app.darkModeEnabled ? 'Use light' : 'Use dark',
                    actionIcon: app.darkModeEnabled
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_rounded,
                    onAction: () =>
                        app.setDarkModeEnabled(!app.darkModeEnabled),
                    titleSize: 33,
                    titleWidthFactor: .72,
                  ),
                  const SizedBox(height: 22),
                  const Eyebrow('PRIVACY & CONTACT'),
                  const SizedBox(height: 9),
                  SoftPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      children: [
                        _SettingToggleRow(
                          icon: Icons.person_outline_rounded,
                          title: 'Show me in student search',
                          subtitle: 'Your school and subjects remain private.',
                          value: _publicProfile,
                          onChanged: (value) =>
                              _savePrivacy(app, publicProfile: value),
                        ),
                        Divider(height: 1, color: context.appLine),
                        _SettingToggleRow(
                          icon: Icons.mail_outline_rounded,
                          title: 'Allow message requests',
                          subtitle: 'New conversations wait for your approval.',
                          value: _allowMessageRequests,
                          onChanged: (value) =>
                              _savePrivacy(app, allowMessageRequests: value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SectionHeading(
                    'Recent sessions',
                    action: 'View history',
                    onAction: () => _showHistory(context, app),
                  ),
                  const SizedBox(height: 8),
                  SoftPanel(
                    color: context.appRaisedSurface,
                    child: Row(
                      children: [
                        AppIcon(
                          Icons.history_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            app.previewMode
                                ? 'CSC 401 · 72 min of focus'
                                : 'Your sessions stay private to you.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showHistory(context, app),
                          child: const Text('Open'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    decoration: BoxDecoration(
                      color: context.appRaisedSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.appLine),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppIcon(Icons.shield_outlined, color: AppColors.marine),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'You control what other students can find. Progress and study history stay private.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.appMuted,
                                  height: 1.45,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 19),
                  OutlinedButton.icon(
                    onPressed: app.logout,
                    icon: const AppIcon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
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

  Future<void> _showHistory(BuildContext context, AppController app) async {
    List<JsonMap> items = [];
    try {
      items = await app.loadSessionHistory();
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('YOUR STUDY RECORD'),
              const SizedBox(height: 7),
              Text(
                'Sessions that add up.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Text(
                  'Finish your first shared session and it will show up here.',
                )
              else
                for (final item in items.take(12))
                  PremiumListRow(
                    contentPadding: EdgeInsets.zero,
                    leading: AppIcon(
                      Icons.check_circle_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      '${item['room_title'] ?? 'Study session'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${item['preset'] ?? 'focus'} · ${((int.tryParse('${item['focused_seconds'] ?? 0}') ?? 0) / 60).round()} min focused',
                    ),
                  ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: items.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text: AppController.sessionHistoryCsv(items),
                            ),
                          );
                          if (context.mounted) {
                            showAppMessage(
                              context,
                              'Private study history copied as CSV.',
                            );
                          }
                        },
                  icon: const AppIcon(Icons.file_download_outlined),
                  label: const Text('Copy history as CSV'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingToggleRow extends StatelessWidget {
  const _SettingToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: title,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            AppIcon(icon, color: context.appBrandInk, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: context.appMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 190),
              curve: Curves.easeOutCubic,
              width: 46,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? AppColors.red : context.appLine,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedAlign(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
