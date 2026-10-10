import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

class NearbySessionService extends ChangeNotifier {
  NearbySessionService() {
    _central.discovered.listen(_onDiscovered);
    _central.characteristicNotified.listen(_onNotified);
    _central.connectionStateChanged.listen(_onConnectionChanged);
    _peripheral.characteristicWriteRequested.listen(_onWriteRequested);
    _peripheral.characteristicNotifyStateChanged.listen(_onNotifyStateChanged);
  }

  static final instance = NearbySessionService();
  static final serviceUuid = UUID.fromString(
    '5b1fa900-5d1a-4e45-a40a-250172d2b600',
  );
  static final characteristicUuid = UUID.fromString(
    '5b1fa901-5d1a-4e45-a40a-250172d2b600',
  );

  final CentralManager _central = CentralManager();
  final PeripheralManager _peripheral = PeripheralManager();
  final List<DiscoveredEventArgs> discoveries = [];
  final Map<String, _FrameAssembly> _hostAssemblies = {};
  final Map<String, _FrameAssembly> _clientAssemblies = {};
  final Map<String, String> _hostMemberIdByCentral = {};
  final Set<String> _subscribedCentrals = {};
  final Random _random = Random.secure();
  final String _hostMemberId = 'host-local';
  bool isHost = false;
  bool isDiscovering = false;
  bool isConnected = false;
  bool isHosting = false;
  bool busy = false;
  String? errorMessage;
  String? statusMessage;
  String? _connectedPeripheralId;
  String? _currentMemberId;
  Peripheral? _remotePeripheral;
  GATTCharacteristic? _remoteCharacteristic;
  GATTCharacteristic? _localCharacteristic;
  GATTService? _localService;
  Map<String, dynamic> state = {};
  int _nextFrameId = 0;
  Timer? _tick;
  Future<void> _writeQueue = Future.value();
  Future<void> _broadcastQueue = Future.value();

  bool get hasSession => state.isNotEmpty;
  String get myMemberId => isHost ? _hostMemberId : (_currentMemberId ?? '');
  String get title => '${state['title'] ?? 'Nearby study table'}';
  List<Map<String, dynamic>> get members => _mapList(state['members']);
  List<Map<String, dynamic>> get tasks => _mapList(state['tasks']);
  List<Map<String, dynamic>> get messages => _mapList(state['messages']);
  int get remainingSeconds {
    final session = state['session'];
    if (session is! Map) return 0;
    final left = int.tryParse('${session['remaining_seconds'] ?? 0}') ?? 0;
    final endsAt = DateTime.tryParse('${session['ends_at'] ?? ''}')?.toUtc();
    if (session['status'] == 'running' && endsAt != null) {
      return max(0, endsAt.difference(DateTime.now().toUtc()).inSeconds);
    }
    return max(0, left);
  }

  Future<void> startHosting({
    required String title,
    required String subject,
    required String hostName,
  }) async {
    _setBusy(true);
    try {
      await _stopScanning();
      if (Platform.isAndroid && !await _peripheral.authorize()) {
        throw StateError(
          'Bluetooth permission is needed to host a nearby table.',
        );
      }
      final member = {
        'id': _hostMemberId,
        'name': _clean(hostName, 32, fallback: 'Host'),
      };
      state = {
        'id': '${DateTime.now().microsecondsSinceEpoch}',
        'title': _clean(title, 64, fallback: 'Nearby study table'),
        'subject': _clean(subject, 48, fallback: 'Open study'),
        'host_id': _hostMemberId,
        'members': [member],
        'tasks': <Map<String, dynamic>>[],
        'messages': <Map<String, dynamic>>[],
        'session': {
          'phase': 'focus',
          'status': 'ready',
          'remaining_seconds': 1500,
          'ends_at': null,
          'focus_minutes': 25,
          'break_minutes': 5,
          'cycles_completed': 0,
        },
      };
      isHost = true;
      isConnected = true;
      if (_localCharacteristic == null) {
        _localCharacteristic = GATTCharacteristic.mutable(
          uuid: characteristicUuid,
          properties: const [
            GATTCharacteristicProperty.read,
            GATTCharacteristicProperty.write,
            GATTCharacteristicProperty.notify,
          ],
          permissions: const [
            GATTCharacteristicPermission.read,
            GATTCharacteristicPermission.write,
          ],
          descriptors: const [],
        );
        _localService = GATTService(
          uuid: serviceUuid,
          isPrimary: true,
          includedServices: const [],
          characteristics: [_localCharacteristic!],
        );
      }
      await _peripheral.removeAllServices();
      await _peripheral.addService(_localService!);
      await _peripheral.startAdvertising(
        Advertisement(name: 'aLaStudie Nearby', serviceUUIDs: [serviceUuid]),
      );
      isHosting = true;
      statusMessage =
          'Nearby study table is open. Keep this screen active while people join.';
      errorMessage = null;
      _startTicker();
      _broadcastSnapshot();
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyError(error);
      state = {};
      isHost = false;
      isConnected = false;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> startScanning() async {
    _setBusy(true);
    try {
      if (Platform.isAndroid && !await _central.authorize()) {
        throw StateError(
          'Allow nearby-device permission to scan for study tables.',
        );
      }
      discoveries.clear();
      await _central.startDiscovery(serviceUUIDs: [serviceUuid]);
      isDiscovering = true;
      errorMessage = null;
      statusMessage =
          'Scanning nearby over Bluetooth. No location or internet is used.';
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyError(error);
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> stopScanning() => _stopScanning();

  Future<void> _stopScanning() async {
    if (!isDiscovering) return;
    await _central.stopDiscovery();
    isDiscovering = false;
    notifyListeners();
  }

  Future<void> join(
    DiscoveredEventArgs discovery, {
    required String name,
  }) async {
    _setBusy(true);
    try {
      await _stopScanning();
      _remotePeripheral = discovery.peripheral;
      _connectedPeripheralId = discovery.peripheral.uuid.toString();
      _currentMemberId = _newId();
      await _central.connect(discovery.peripheral);
      final services = await _central.discoverGATT(discovery.peripheral);
      final service = services
          .where(
            (item) =>
                item.uuid.toString().toLowerCase() ==
                serviceUuid.toString().toLowerCase(),
          )
          .firstOrNull;
      if (service == null)
        throw StateError('That nearby table is no longer available.');
      _remoteCharacteristic = service.characteristics
          .where(
            (item) =>
                item.uuid.toString().toLowerCase() ==
                characteristicUuid.toString().toLowerCase(),
          )
          .firstOrNull;
      if (_remoteCharacteristic == null)
        throw StateError('Could not open the nearby study link.');
      try {
        await _central.requestMTU(discovery.peripheral, mtu: 185);
      } catch (_) {}
      await _central.setCharacteristicNotifyState(
        discovery.peripheral,
        _remoteCharacteristic!,
        state: true,
      );
      isHost = false;
      isConnected = true;
      errorMessage = null;
      statusMessage = 'Connected nearby. Your session stays on these devices.';
      _startTicker();
      await _sendCommand({
        'type': 'join',
        'client_id': _currentMemberId,
        'name': _clean(name, 32, fallback: 'Student'),
      });
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyError(error);
      isConnected = false;
      notifyListeners();
      await _disconnectClient();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> addTask(String title) async {
    final cleanTitle = _clean(title, 100, fallback: 'Study task');
    if (isHost) {
      _handleCommand(_hostMemberId, {'type': 'task_add', 'title': cleanTitle});
    } else {
      await _sendCommand({'type': 'task_add', 'title': cleanTitle});
    }
  }

  Future<void> toggleTask(String taskId) async {
    if (isHost) {
      _handleCommand(_hostMemberId, {'type': 'task_toggle', 'task_id': taskId});
    } else {
      await _sendCommand({'type': 'task_toggle', 'task_id': taskId});
    }
  }

  Future<void> sendMessage(String body) async {
    final cleanBody = _clean(body, 240, fallback: '');
    if (cleanBody.isEmpty) return;
    if (isHost) {
      _handleCommand(_hostMemberId, {'type': 'chat', 'body': cleanBody});
    } else {
      await _sendCommand({'type': 'chat', 'body': cleanBody});
    }
  }

  Future<void> startTimer({
    required int focusMinutes,
    required int breakMinutes,
  }) async {
    final safeFocus = focusMinutes.clamp(1, 180);
    final safeBreak = breakMinutes.clamp(0, 60);
    await _timerCommand(
      'start',
      focusMinutes: safeFocus,
      breakMinutes: safeBreak,
    );
  }

  Future<void> controlTimer(String action) async => _timerCommand(action);

  Future<void> _timerCommand(
    String action, {
    int? focusMinutes,
    int? breakMinutes,
  }) async {
    final command = {
      'type': 'timer',
      'action': action,
      if (focusMinutes != null) 'focus_minutes': focusMinutes,
      if (breakMinutes != null) 'break_minutes': breakMinutes,
    };
    if (isHost) {
      _handleCommand(_hostMemberId, command);
    } else {
      await _sendCommand(command);
    }
  }

  Future<void> closeSession() async {
    _tick?.cancel();
    _tick = null;
    if (isHosting) {
      try {
        final connected = await _peripheral.retrieveConnectedCentrals();
        for (final central in connected) {
          if (_subscribedCentrals.contains(central.uuid.toString())) {
            await _sendSnapshotTo(central, message: {'type': 'closed'});
          }
        }
        await _peripheral.stopAdvertising();
        await _peripheral.removeAllServices();
      } catch (_) {}
    }
    if (!isHost) await _disconnectClient();
    state = {};
    isHost = false;
    isHosting = false;
    isConnected = false;
    _remoteCharacteristic = null;
    _remotePeripheral = null;
    _connectedPeripheralId = null;
    _currentMemberId = null;
    _hostMemberIdByCentral.clear();
    _subscribedCentrals.clear();
    statusMessage = 'Nearby table closed on this device.';
    notifyListeners();
  }

  void _onDiscovered(DiscoveredEventArgs event) {
    if (!event.advertisement.serviceUUIDs.any(
      (uuid) =>
          uuid.toString().toLowerCase() == serviceUuid.toString().toLowerCase(),
    ))
      return;
    final index = discoveries.indexWhere(
      (item) => item.peripheral.uuid == event.peripheral.uuid,
    );
    if (index < 0) {
      discoveries.add(event);
    } else {
      discoveries[index] = event;
    }
    discoveries.sort((a, b) => b.rssi.compareTo(a.rssi));
    notifyListeners();
  }

  void _onConnectionChanged(PeripheralConnectionStateChangedEventArgs event) {
    if (_connectedPeripheralId != event.peripheral.uuid.toString()) return;
    if (event.state == ConnectionState.disconnected) {
      _tick?.cancel();
      _tick = null;
      isConnected = false;
      state = {};
      _remotePeripheral = null;
      _remoteCharacteristic = null;
      _connectedPeripheralId = null;
      _currentMemberId = null;
      statusMessage = 'The nearby table connection ended.';
      notifyListeners();
    }
  }

  void _onNotified(GATTCharacteristicNotifiedEventArgs event) {
    if (_remotePeripheral == null ||
        event.peripheral.uuid != _remotePeripheral!.uuid ||
        event.characteristic.uuid.toString() != characteristicUuid.toString())
      return;
    final packet = event.value;
    if (packet.length < 6) return;
    final decoded = _addFrame(_clientAssemblies, 'host', packet);
    if (decoded != null) _receiveSnapshot(decoded);
  }

  Future<void> _onWriteRequested(
    GATTCharacteristicWriteRequestedEventArgs event,
  ) async {
    final request = event.request;
    try {
      await _peripheral.respondWriteRequest(request);
      if (event.characteristic.uuid.toString() !=
              characteristicUuid.toString() ||
          request.value.length < 6)
        return;
      final sender = event.central.uuid.toString();
      final decoded = _addFrame(_hostAssemblies, sender, request.value);
      if (decoded != null) _handleCommand(sender, decoded);
    } catch (_) {}
  }

  Future<void> _onNotifyStateChanged(
    GATTCharacteristicNotifyStateChangedEventArgs event,
  ) async {
    if (event.characteristic.uuid.toString() != characteristicUuid.toString())
      return;
    final centralId = event.central.uuid.toString();
    if (event.state) {
      _subscribedCentrals.add(centralId);
      await _sendSnapshotTo(event.central);
    } else {
      _subscribedCentrals.remove(centralId);
    }
  }

  void _handleCommand(String senderId, Map<String, dynamic> command) {
    final type = '${command['type'] ?? ''}';
    final currentMembers = members;
    if (type == 'join' && isHost) {
      final memberId = _clean(
        command['client_id']?.toString() ?? '',
        72,
        fallback: _newId(),
      );
      _hostMemberIdByCentral[senderId] = memberId;
      if (!currentMembers.any((member) => member['id'] == memberId) &&
          currentMembers.length < 16) {
        currentMembers.add({
          'id': memberId,
          'name': _clean(
            command['name']?.toString() ?? '',
            32,
            fallback: 'Nearby student',
          ),
        });
        state['members'] = currentMembers;
        _publishState();
      }
      return;
    }
    final memberId = senderId == _hostMemberId
        ? _hostMemberId
        : (_hostMemberIdByCentral[senderId] ?? senderId);
    final isKnownMember = currentMembers.any(
      (member) => member['id'] == memberId,
    );
    if (!isKnownMember) return;
    if (type == 'task_add') {
      final title = _clean(
        command['title']?.toString() ?? '',
        100,
        fallback: '',
      );
      if (title.isEmpty || tasks.length >= 60) return;
      final updated = tasks;
      updated.add({'id': _newId(), 'title': title, 'completed_by': <String>[]});
      state['tasks'] = updated;
      _publishState();
    } else if (type == 'task_toggle') {
      final taskId = '${command['task_id'] ?? ''}';
      final updated = tasks.map((task) {
        if ('${task['id']}' != taskId) return task;
        final completedBy = (task['completed_by'] as List? ?? [])
            .map((id) => '$id')
            .toSet();
        if (!completedBy.add(memberId)) completedBy.remove(memberId);
        return {...task, 'completed_by': completedBy.toList()};
      }).toList();
      state['tasks'] = updated;
      _publishState();
    } else if (type == 'chat') {
      final body = _clean(command['body']?.toString() ?? '', 240, fallback: '');
      if (body.isEmpty || messages.length >= 200) return;
      final author = currentMembers.firstWhere(
        (member) => member['id'] == memberId,
        orElse: () => {'name': 'Nearby student'},
      );
      final updated = messages;
      updated.add({
        'id': _newId(),
        'sender_id': memberId,
        'sender_name': author['name'],
        'body': body,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      state['messages'] = updated;
      _publishState();
    } else if (type == 'timer' && memberId == _hostMemberId && isHost) {
      _applyTimerCommand(command);
    }
  }

  void _applyTimerCommand(Map<String, dynamic> command) {
    final current = Map<String, dynamic>.from(state['session'] as Map);
    final action = '${command['action'] ?? ''}';
    if (action == 'start') {
      final focus = int.tryParse('${command['focus_minutes']}') ?? 25;
      final rest = int.tryParse('${command['break_minutes']}') ?? 5;
      current.addAll({
        'phase': 'focus',
        'status': 'running',
        'focus_minutes': focus.clamp(1, 180),
        'break_minutes': rest.clamp(0, 60),
        'remaining_seconds': focus * 60,
        'ends_at': DateTime.now()
            .toUtc()
            .add(Duration(minutes: focus))
            .toIso8601String(),
        'cycles_completed': 0,
      });
    } else if (action == 'pause' && current['status'] == 'running') {
      current['remaining_seconds'] = remainingSeconds;
      current['ends_at'] = null;
      current['status'] = 'paused';
    } else if (action == 'resume' && current['status'] == 'paused') {
      final seconds = int.tryParse('${current['remaining_seconds']}') ?? 0;
      current['ends_at'] = DateTime.now()
          .toUtc()
          .add(Duration(seconds: seconds))
          .toIso8601String();
      current['status'] = 'running';
    } else if (action == 'finish') {
      current['status'] = 'finished';
      current['remaining_seconds'] = 0;
      current['ends_at'] = null;
    } else {
      return;
    }
    state['session'] = current;
    _publishState();
  }

  void _startTicker() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isHost && hasSession && remainingSeconds == 0) _advanceTimerPhase();
      notifyListeners();
    });
  }

  void _advanceTimerPhase() {
    final current = Map<String, dynamic>.from(state['session'] as Map);
    if (current['status'] != 'running') return;
    if (current['phase'] == 'focus') {
      final breakMinutes = int.tryParse('${current['break_minutes']}') ?? 5;
      final cycles = (int.tryParse('${current['cycles_completed']}') ?? 0) + 1;
      if (breakMinutes == 0) {
        current.addAll({
          'phase': 'focus',
          'status': 'finished',
          'remaining_seconds': 0,
          'ends_at': null,
          'cycles_completed': cycles,
        });
      } else {
        current.addAll({
          'phase': 'break',
          'remaining_seconds': breakMinutes * 60,
          'ends_at': DateTime.now()
              .toUtc()
              .add(Duration(minutes: breakMinutes))
              .toIso8601String(),
          'cycles_completed': cycles,
        });
      }
    } else {
      final focusMinutes = int.tryParse('${current['focus_minutes']}') ?? 25;
      current.addAll({
        'phase': 'focus',
        'remaining_seconds': focusMinutes * 60,
        'ends_at': DateTime.now()
            .toUtc()
            .add(Duration(minutes: focusMinutes))
            .toIso8601String(),
      });
    }
    state['session'] = current;
    _publishState();
  }

  void _receiveSnapshot(Map<String, dynamic> next) {
    if (next['type'] == 'closed') {
      _tick?.cancel();
      _tick = null;
      state = {};
      isConnected = false;
      statusMessage = 'The host closed the nearby table.';
      unawaited(_disconnectClient());
      notifyListeners();
      return;
    }
    if (next['type'] == 'snapshot' && next['state'] is Map) {
      state = (next['state'] as Map).cast<String, dynamic>();
      isConnected = true;
      if (!isHost && _tick == null) _startTicker();
      notifyListeners();
    }
  }

  void _publishState() {
    notifyListeners();
    _broadcastSnapshot();
  }

  void _broadcastSnapshot() {
    if (!isHost || !isHosting) return;
    final frame = {'type': 'snapshot', 'state': _boundedState()};
    _broadcastQueue = _broadcastQueue
        .then((_) async {
          final connected = await _peripheral.retrieveConnectedCentrals();
          for (final central in connected) {
            if (_subscribedCentrals.contains(central.uuid.toString())) {
              await _sendSnapshotTo(central, message: frame);
            }
          }
        })
        .catchError((_) {});
  }

  Map<String, dynamic> _boundedState() => {
    ...state,
    'members': members.take(16).toList(),
    'tasks': tasks.take(60).toList(),
    'messages': messages.take(60).toList(),
    'session': Map<String, dynamic>.from(state['session'] as Map),
  };

  Future<void> _sendSnapshotTo(
    Central central, {
    Map<String, dynamic>? message,
  }) async {
    final characteristic = _localCharacteristic;
    if (characteristic == null) return;
    final payload = message ?? {'type': 'snapshot', 'state': _boundedState()};
    for (final frame in _frames(payload)) {
      await _peripheral.notifyCharacteristic(
        central,
        characteristic,
        value: frame,
      );
    }
  }

  Future<void> _sendCommand(Map<String, dynamic> command) async {
    final peripheral = _remotePeripheral;
    final characteristic = _remoteCharacteristic;
    if (!isConnected || peripheral == null || characteristic == null) {
      errorMessage = 'Connect to a nearby table first.';
      notifyListeners();
      return;
    }
    _writeQueue = _writeQueue.then((_) async {
      for (final frame in _frames(command)) {
        await _central.writeCharacteristic(
          peripheral,
          characteristic,
          value: frame,
          type: GATTCharacteristicWriteType.withResponse,
        );
      }
    });
    try {
      await _writeQueue;
    } catch (error) {
      errorMessage = _friendlyError(error);
      notifyListeners();
    }
  }

  List<Uint8List> _frames(Map<String, dynamic> message) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(message)));
    const payloadSize = 14;
    final total = max(1, (bytes.length / payloadSize).ceil());
    final id = (_nextFrameId++ & 0xffff);
    return List.generate(total, (part) {
      final start = part * payloadSize;
      final end = min(bytes.length, start + payloadSize);
      final frame = Uint8List(6 + end - start);
      final header = ByteData.sublistView(frame);
      header.setUint16(0, id, Endian.big);
      header.setUint16(2, part, Endian.big);
      header.setUint16(4, total, Endian.big);
      frame.setRange(6, frame.length, bytes, start);
      return frame;
    });
  }

  Map<String, dynamic>? _addFrame(
    Map<String, _FrameAssembly> assemblies,
    String source,
    Uint8List frame,
  ) {
    final header = ByteData.sublistView(frame);
    final id = header.getUint16(0, Endian.big);
    final index = header.getUint16(2, Endian.big);
    final total = header.getUint16(4, Endian.big);
    if (total == 0 || total > 4096 || index >= total) return null;
    final key = '$source:$id';
    final assembly = assemblies.putIfAbsent(key, () => _FrameAssembly(total));
    if (assembly.total != total) {
      assemblies.remove(key);
      return null;
    }
    assembly.parts[index] = Uint8List.fromList(frame.sublist(6));
    if (assembly.parts.length != total) return null;
    assemblies.remove(key);
    final bytes = BytesBuilder(copy: false);
    for (var part = 0; part < total; part++) {
      final value = assembly.parts[part];
      if (value == null) return null;
      bytes.add(value);
    }
    try {
      return (jsonDecode(utf8.decode(bytes.takeBytes())) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _disconnectClient() async {
    final peripheral = _remotePeripheral;
    if (peripheral != null) {
      try {
        await _central.disconnect(peripheral);
      } catch (_) {}
    }
    _remotePeripheral = null;
    _remoteCharacteristic = null;
    _connectedPeripheralId = null;
    _currentMemberId = null;
    isConnected = false;
  }

  String _clean(String value, int maxLength, {String fallback = ''}) {
    final cleaned = value
        .replaceAll(RegExp(r'[\r\n\u0000-\u001f]'), ' ')
        .trim();
    return cleaned.isEmpty
        ? fallback
        : cleaned.substring(0, min(cleaned.length, maxLength));
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}';

  String _friendlyError(Object error) {
    final text = '$error';
    if (text.contains('permission') || text.contains('Permission'))
      return text.replaceFirst('Bad state: ', '');
    if (text.contains('Bluetooth') || text.contains('bluetooth'))
      return 'Turn on Bluetooth and try again.';
    return 'Nearby connection could not start. Keep both devices close and try again.';
  }

  void _setBusy(bool value) {
    busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

class _FrameAssembly {
  _FrameAssembly(this.total);
  final int total;
  final Map<int, Uint8List> parts = {};
}

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
    : <Map<String, dynamic>>[];
