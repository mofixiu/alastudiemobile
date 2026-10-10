import 'package:socket_io_client/socket_io_client.dart' as IO;

class RealtimeService {
  IO.Socket? _socket;
  final Set<String> _subscriptions = {};
  final Map<String, String> _presenceByRoom = {};

  void connect(
    String baseUrl,
    String token,
    void Function(String event, dynamic payload) onEvent,
  ) {
    disconnect();
    final socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    for (final event in [
      'presence:snapshot',
      'session:update',
      'room:message',
      'room:message_changed',
      'room:member_joined',
      'room:role_changed',
      'room:removed',
      'task:changed',
      'task:removed',
      'task:completion',
      'notification:new',
      'direct:message',
      'direct:message_changed',
    ]) {
      socket.on(event, (payload) => onEvent(event, payload));
    }
    socket.on('connect', (_) {
      onEvent('socket:connect', null);
      for (final roomId in _subscriptions) {
        socket.emit('room:subscribe', {'roomId': roomId});
        final presence = _presenceByRoom[roomId];
        if (presence != null) {
          socket.emit('presence:update', {
            'roomId': roomId,
            'status': presence,
          });
        }
      }
    });
    socket.connect();
    _socket = socket;
  }

  void subscribe(String roomId) {
    _subscriptions.add(roomId);
    if (_socket?.connected == true) {
      _socket!.emit('room:subscribe', {'roomId': roomId});
    }
  }

  void unsubscribe(String roomId) {
    _subscriptions.remove(roomId);
    _presenceByRoom.remove(roomId);
    if (_socket?.connected == true) {
      _socket!.emit('room:unsubscribe', {'roomId': roomId});
    }
  }

  void updatePresence(String roomId, String status) {
    _presenceByRoom[roomId] = status;
    if (_socket?.connected == true) {
      _socket!.emit('presence:update', {'roomId': roomId, 'status': status});
    }
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _subscriptions.clear();
    _presenceByRoom.clear();
  }
}
