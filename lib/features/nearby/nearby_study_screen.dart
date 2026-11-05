import 'dart:async';

import '../../shared/widgets/app_icon.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui.dart';
import '../app/app_controller.dart';
import 'nearby_session_service.dart';

class NearbyStudyScreen extends StatefulWidget {
  const NearbyStudyScreen({super.key});

  @override
  State<NearbyStudyScreen> createState() => _NearbyStudyScreenState();
}

class _NearbyStudyScreenState extends State<NearbyStudyScreen> {
  final service = NearbySessionService.instance;
  final _chatInput = TextEditingController();
  bool _hasSavedHost = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreLocalSession());
  }

  Future<void> _restoreLocalSession() async {
    final hostAvailable = await service.hasSavedHostSnapshot;
    if (hostAvailable) {
      if (mounted) setState(() => _hasSavedHost = true);
    } else {
      await service.restoreSavedGuest();
    }
  }

  @override
  void dispose() {
    _chatInput.dispose();
    if (service.isDiscovering) unawaited(service.stopScanning());
    super.dispose();
  }

  Future<void> _goBack() async {
    if (service.isHosting || service.isConnected) {
      final leave = await showBrandedDialog<bool>(
        context: context,
        builder: (context) => PremiumDialogSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('LOCAL TABLE'),
              const SizedBox(height: 7),
              Text(
                'Leave this table?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'The group chat is discarded when the table ends. If you are signed in, a private focus summary will sync when the backend is reachable.',
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Stay'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Leave table'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      if (leave != true || !mounted) return;
      final summary = service.summary();
      await context.read<AppController>().recordNearbySummary(summary);
      await service.closeSession();
    } else if (service.isDiscovering) {
      await service.stopScanning();
    }
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _host() async {
    final title = TextEditingController(text: 'Quiet study table');
    final subject = TextEditingController(text: 'Open study');
    final draft = await showPremiumBottomSheet<_NearbyRoomDraft>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('A TABLE FOR THE PEOPLE AROUND YOU'),
              const SizedBox(height: 7),
              Text(
                'Set the scene',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: title,
                maxLength: 64,
                decoration: const InputDecoration(labelText: 'Room name'),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: subject,
                maxLength: 48,
                decoration: const InputDecoration(
                  labelText: 'Subject or course',
                ),
              ),
              const SizedBox(height: 13),
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  _NearbyRoomDraft(title.text.trim(), subject.text.trim()),
                ),
                icon: const AppIcon(
                  Icons.bluetooth_searching_rounded,
                  size: 14,
                ),
                label: const Text('Open nearby table'),
              ),
            ],
          ),
        ),
      ),
    );
    title.dispose();
    subject.dispose();
    if (draft == null || !mounted) return;
    final app = context.read<AppController>();
    await service.startHosting(
      title: draft.title,
      subject: draft.subject,
      hostName: app.displayName,
    );
    if (mounted && service.errorMessage != null)
      showAppMessage(context, service.errorMessage);
  }

  Future<void> _join(DiscoveredEventArgs item) async {
    final app = context.read<AppController>();
    await service.join(item, name: app.displayName);
    if (mounted && service.errorMessage != null)
      showAppMessage(context, service.errorMessage);
  }

  Future<void> _addTask() async {
    final text = TextEditingController();
    final value = await showPremiumBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('SHARED WITH THIS TABLE'),
              const SizedBox(height: 7),
              Text(
                'Add a next step',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 13),
              TextField(
                controller: text,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(
                  hintText: 'What should the group finish?',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, text.text.trim()),
                icon: const AppIcon(Icons.arrow_forward_rounded),
                label: const Text('Add to table'),
              ),
            ],
          ),
        ),
      ),
    );
    text.dispose();
    if (value != null && value.trim().isNotEmpty) await service.addTask(value);
  }

  Future<void> _startTimer(int focus, int rest) async {
    await service.startTimer(focusMinutes: focus, breakMinutes: rest);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) => PopScope(
      canPop: !service.hasSession,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_goBack());
      },
      child: Scaffold(
        body: SafeArea(
          top: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              BrandGlassSliverBar(
                leading: IconButton(
                  onPressed: _goBack,
                  icon: const AppIcon(Icons.arrow_back_rounded),
                  tooltip: 'Back',
                ),
                actions: [
                  if (service.busy)
                    const SizedBox(
                      width: 45,
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                sliver: SliverList.list(
                  children: [
                    const SizedBox(height: 5),
                    if (service.hasSession)
                      _sessionContents()
                    else
                      _discoveryContents(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _discoveryContents() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BrandFeaturePanel(
        eyebrow: 'NO SIGNAL · STILL IN SYNC',
        title: 'Study,\nnearby.',
        description:
            'Find the people around you with Bluetooth. Then work together without an internet connection.',
        actionLabel: 'Host a table',
        actionIcon: Icons.add_rounded,
        onAction: service.busy ? () {} : () => unawaited(_host()),
        titleSize: 36,
        titleWidthFactor: .75,
      ),
      if (_hasSavedHost && !service.isHosting) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: service.busy
              ? null
              : () async {
                  final resumed = await service.resumeSavedHost();
                  if (resumed && mounted) setState(() => _hasSavedHost = false);
                },
          icon: const AppIcon(Icons.restart_alt_rounded, size: 17),
          label: const Text('Resume your nearby table'),
        ),
      ],
      const SizedBox(height: 16),
      SoftPanel(
        color: context.appSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('DEVICE TO DEVICE'),
            const SizedBox(height: 5),
            const Text(
              'No account sign-in. No GPS. No server.',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Bluetooth must be on. The host keeps this screen open so everyone shares the same timer, chat, and tasks.',
              style: TextStyle(color: context.appMuted, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Android 11 and earlier may ask for location permission to scan Bluetooth devices. aLaStudie does not read GPS or collect your location.',
              style: TextStyle(
                color: context.appMuted,
                height: 1.35,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: service.busy
            ? null
            : () => unawaited(
                service.isDiscovering
                    ? service.stopScanning()
                    : service.startScanning(),
              ),
        icon: AppIcon(
          service.isDiscovering
              ? Icons.stop_rounded
              : Icons.bluetooth_searching_rounded,
          size: 14,
        ),
        label: Text(
          service.isDiscovering ? 'Stop scanning' : 'Find nearby study tables',
        ),
      ),
      if (service.statusMessage != null) ...[
        const SizedBox(height: 9),
        Text(
          service.statusMessage!,
          style: TextStyle(color: context.appMuted, fontSize: 12),
        ),
      ],
      if (service.errorMessage != null) ...[
        const SizedBox(height: 9),
        InlineErrorNotice(service.errorMessage!),
      ],
      const SizedBox(height: 20),
      Row(
        children: [
          const Expanded(child: SectionHeading('Around you')),
          if (service.isDiscovering)
            const SizedBox(
              width: 42,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
      const SizedBox(height: 9),
      if (!service.isDiscovering && service.discoveries.isEmpty)
        const SoftPanel(
          child: Text(
            'Nearby tables appear here while their host is broadcasting.',
          ),
        )
      else if (service.discoveries.isEmpty)
        const SoftPanel(
          child: Text(
            'Listening for aLaStudie tables… Keep both phones nearby.',
          ),
        )
      else
        for (var i = 0; i < service.discoveries.length; i++)
          OneShotReveal(
            key: ValueKey(service.discoveries[i].peripheral.uuid),
            index: i,
            distance: 10,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _discoveryTile(service.discoveries[i]),
            ),
          ),
      const SizedBox(height: 12),
      Text(
        'Nearby chat stays on these devices and is discarded at session end. A private focus summary can sync to your account when you are online.',
        style: TextStyle(color: context.appMuted, fontSize: 11, height: 1.4),
      ),
    ],
  );

  Widget _discoveryTile(DiscoveredEventArgs item) => SoftPanel(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: context.appBrandPanel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const AppIcon(
            Icons.bluetooth_rounded,
            size: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nearby study table',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                '${_signalLabel(item.rssi)} · open to join',
                style: TextStyle(color: context.appMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: service.busy ? null : () => _join(item),
          child: const Text('Join'),
        ),
      ],
    ),
  );

  Widget _sessionContents() {
    final session = service.state['session'] is Map
        ? (service.state['session'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final phase = '${session['phase'] ?? 'focus'}';
    final status = '${session['status'] ?? 'ready'}';
    final minutes = (service.remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (service.remainingSeconds % 60).toString().padLeft(2, '0');
    final focus =
        (int.tryParse('${session['focus_minutes'] ?? 25}') ?? 25) * 60;
    final progress = focus == 0
        ? 0.0
        : (service.remainingSeconds / focus).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrandFeaturePanel(
          eyebrow: 'LOCAL TABLE · NO INTERNET',
          title: service.title,
          description:
              '${service.state['subject'] ?? 'Open study'} · shared directly between the phones around you.',
          titleSize: 33,
          titleWidthFactor: .72,
          actionLabel: service.isHost ? 'Close this table' : 'Leave this table',
          actionIcon: Icons.logout_rounded,
          onAction: service.closeSession,
        ),
        const SizedBox(height: 18),
        _timerPanel(phase, status, '$minutes:$seconds', progress),
        if (!service.isHost && !service.isConnected) ...[
          const SizedBox(height: 11),
          SoftPanel(
            color: context.appBrandPanel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('CONNECTION PAUSED'),
                const SizedBox(height: 4),
                const Text(
                  'Reconnect to the same host',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your saved timer, people, messages and tasks stay on this device until the host sends the current snapshot.',
                  style: TextStyle(color: context.appMuted, fontSize: 11),
                ),
                const SizedBox(height: 7),
                FilledButton.icon(
                  onPressed: service.busy
                      ? null
                      : () => service.isDiscovering
                            ? service.stopScanning()
                            : service.startScanning(),
                  icon: AppIcon(
                    service.isDiscovering
                        ? Icons.stop_rounded
                        : Icons.bluetooth_searching_rounded,
                    size: 15,
                  ),
                  label: Text(
                    service.isDiscovering
                        ? 'Stop scanning'
                        : 'Scan for the same host',
                  ),
                ),
                for (final item in service.discoveries) _discoveryTile(item),
              ],
            ),
          ),
        ],
        const SizedBox(height: 19),
        Row(
          children: [
            const Expanded(child: SectionHeading('Around this table')),
            StatusTag(
              '${service.members.length} HERE',
              color: AppColors.red,
              textColor: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 9),
        SoftPanel(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final member in service.members)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(color: context.appLine),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        member['id'] == service.state['host_id']
                            ? Icons.workspace_premium_rounded
                            : Icons.person_outline_rounded,
                        size: 15,
                        color: context.appBrandInk,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${member['name'] ?? 'Student'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 19),
        Row(
          children: [
            const Expanded(child: SectionHeading('Shared next steps')),
            TextButton.icon(
              onPressed: (!service.isConnected && !service.isHost)
                  ? null
                  : _addTask,
              icon: const AppIcon(Icons.add_rounded),
              label: const Text('Add task'),
            ),
          ],
        ),
        const SizedBox(height: 7),
        if (service.tasks.isEmpty)
          const SoftPanel(
            child: Text(
              'Add a first task to give the table a shared starting point.',
            ),
          )
        else
          for (final task in service.tasks)
            IgnorePointer(
              ignoring: !service.isConnected && !service.isHost,
              child: Opacity(
                opacity: (!service.isConnected && !service.isHost) ? .55 : 1,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _taskTile(task),
                ),
              ),
            ),
        const SizedBox(height: 15),
        const SectionHeading('Room chat'),
        const SizedBox(height: 8),
        _chatPanel(),
        const SizedBox(height: 8),
        Text(
          'Only these nearby phones have this conversation. It disappears when the table closes.',
          style: TextStyle(color: context.appMuted, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _timerPanel(
    String phase,
    String status,
    String time,
    double progress,
  ) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: context.appBrandPanel,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Eyebrow(
              '${phase == 'focus' ? 'FOCUS' : 'BREAK'} · ${status.toUpperCase()}',
            ),
            const Spacer(),
            AppIcon(
              service.isHost
                  ? Icons.workspace_premium_rounded
                  : Icons.devices_rounded,
              color: AppColors.red,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 55,
            fontWeight: FontWeight.w900,
            letterSpacing: -2.8,
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 5,
            child: Stack(
              children: [
                Container(color: Colors.white24),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: const ColoredBox(color: AppColors.red),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (service.isHost)
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (status == 'ready' || status == 'finished')
                _timerButton('25 / 5', () => _startTimer(25, 5)),
              if (status == 'ready' || status == 'finished')
                _timerButton('50 / 10', () => _startTimer(50, 10)),
              if (status == 'running')
                _timerButton('Pause', () => service.controlTimer('pause')),
              if (status == 'paused')
                _timerButton('Resume', () => service.controlTimer('resume')),
              if (status == 'running' || status == 'paused')
                _timerButton('Finish', () => service.controlTimer('finish')),
            ],
          )
        else
          const Text(
            'The table host leads the shared timer.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
      ],
    ),
  );

  Widget _timerButton(String label, VoidCallback onPressed) => OutlinedButton(
    onPressed: service.busy ? null : onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white54),
    ),
    child: Text(label),
  );

  Widget _taskTile(Map<String, dynamic> task) {
    final completedBy = (task['completed_by'] as List? ?? [])
        .map((id) => '$id')
        .toSet();
    final completed = completedBy.contains(service.myMemberId);
    return SoftPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: PremiumListRow(
        onTap: () => service.toggleTask('${task['id']}'),
        leading: PremiumCheckbox(
          value: completed,
          onChanged: (_) => service.toggleTask('${task['id']}'),
        ),
        title: Text(
          '${task['title']}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            decoration: completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${completedBy.length} of ${service.members.length} finished',
          style: TextStyle(color: context.appMuted, fontSize: 11),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _chatPanel() => SoftPanel(
    padding: const EdgeInsets.all(11),
    child: Column(
      children: [
        if (service.messages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Text('First note gets the table started.'),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.builder(
              reverse: true,
              itemCount: service.messages.length,
              itemBuilder: (context, index) {
                final message =
                    service.messages[service.messages.length - index - 1];
                final isMine = message['sender_id'] == service.myMemberId;
                return OneShotReveal(
                  key: ValueKey(message['id']),
                  index: index,
                  distance: 8,
                  child: Align(
                    alignment: isMine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isMine
                            ? context.appBrandPanel
                            : context.appRaisedSurface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(15),
                          topRight: const Radius.circular(15),
                          bottomLeft: Radius.circular(isMine ? 15 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${message['sender_name'] ?? 'Student'}',
                            style: TextStyle(
                              color: isMine ? Colors.white70 : context.appMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${message['body'] ?? ''}',
                            style: TextStyle(
                              color: isMine ? Colors.white : context.appInk,
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
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatInput,
                enabled: service.isConnected || service.isHost,
                textInputAction: TextInputAction.send,
                maxLength: 240,
                decoration: const InputDecoration(
                  hintText: 'Leave a useful note',
                  counterText: '',
                ),
                onSubmitted: (_) => _sendChat(),
              ),
            ),
            const SizedBox(width: 7),
            IconButton.filled(
              onPressed: (service.isConnected || service.isHost)
                  ? _sendChat
                  : null,
              icon: const AppIcon(Icons.arrow_upward_rounded),
              tooltip: 'Send message',
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _sendChat() async {
    final text = _chatInput.text.trim();
    if (text.isEmpty) return;
    _chatInput.clear();
    await service.sendMessage(text);
  }

  String _signalLabel(int rssi) => rssi > -58
      ? 'Close by'
      : rssi > -76
      ? 'In range'
      : 'Weak signal';
}

class _NearbyRoomDraft {
  const _NearbyRoomDraft(this.title, this.subject);
  final String title;
  final String subject;
}
