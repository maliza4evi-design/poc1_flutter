import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/connection_models.dart';

const String SERVICE_ID = 'com.example.poc1_flutter.chat';
const String STRATEGY = 'P2P_CLUSTER';

class NearbyService {
  final NearbyConnections _nearby = NearbyConnections();
  final StreamController<PeerDevice> _discoveredPeerController = StreamController.broadcast();
  final StreamController<ConnectionState> _stateController = StreamController.broadcast();
  final StreamController<ChatMessage> _messageController = StreamController.broadcast();
  final StreamController<String> _errorController = StreamController.broadcast();

  Stream<PeerDevice> get discoveredPeers => _discoveredPeerController.stream;
  Stream<ConnectionState> get stateChanges => _stateController.stream;
  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<String> get errors => _errorController.stream;

  ConnectionState _currentState = ConnectionState.disconnected;
  ConnectionState get currentState => _currentState;

  final Map<String, PeerDevice> _discoveredPeers = {};
  final Map<String, StreamSubscription> _payloadSubscriptions = {};
  String? _localEndpointId;
  String? _connectedEndpointId;
  String? _localEndpointName;
  bool _isInitialized = false;

  Future<bool> initialize({required String localName}) async {
    if (_isInitialized) return true;
    
    _localEndpointName = localName;
    
    try {
      final hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        _errorController.add('Permissions denied');
        return false;
      }

      await _nearby.initialize(
        serviceId: SERVICE_ID,
        strategy: Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        onPayloadReceived: _onPayloadReceived,
        onPayloadTransferUpdate: _onPayloadTransferUpdate,
      );

      _isInitialized = true;
      _updateState(ConnectionState.disconnected);
      _log('Nearby Connections initialized');
      return true;
    } catch (e, stack) {
      _log('Initialization failed: $e', level: 1000, error: e, stackTrace: stack);
      _errorController.add('Initialization failed: $e');
      return false;
    }
  }

  Future<bool> _requestPermissions() async {
    final permissions = <Permission>[
      Permission.location,
      Permission.nearbyWifiDevices,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ];

    // For Android 12+, we need nearby wifi devices instead of location
    final androidInfo = await _getAndroidVersion();
    if (androidInfo >= 33) {
      permissions.remove(Permission.location);
    }

    final results = await Future.wait(permissions.map((p) => p.request()));
    return results.every((status) => status.isGranted);
  }

  Future<int> _getAndroidVersion() async {
    // This would need platform channel in real implementation
    // For now, assume modern Android
    return 33;
  }

  void _updateState(ConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
      _log('State changed: $newState');
    }
  }

  void _log(String message, {int level = 800, dynamic error, StackTrace? stackTrace}) {
    developer.log(message, name: 'NearbyService', level: level, error: error, stackTrace: stackTrace);
  }

  // Discovery
  Future<void> startDiscovery() async {
    if (!_isInitialized) return;
    try {
      _updateState(ConnectionState.discovering);
      await _nearby.startDiscovery(
        serviceId: SERVICE_ID,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          _log('Endpoint found: $endpointId ($endpointName)');
          final peer = PeerDevice(
            endpointId: endpointId,
            endpointName: endpointName,
            serviceId: serviceId,
          );
          _discoveredPeers[endpointId] = peer;
          _discoveredPeerController.add(peer);
        },
        onEndpointLost: (endpointId) {
          _log('Endpoint lost: $endpointId');
          _discoveredPeers.remove(endpointId);
        },
      );
    } catch (e) {
      _errorController.add('Discovery failed: $e');
      _updateState(ConnectionState.error);
    }
  }

  Future<void> stopDiscovery() async {
    try {
      await _nearby.stopDiscovery();
      _log('Discovery stopped');
    } catch (e) {
      _log('Stop discovery error: $e', level: 900);
    }
  }

  // Advertising
  Future<void> startAdvertising() async {
    if (!_isInitialized) return;
    try {
      _updateState(ConnectionState.advertising);
      await _nearby.startAdvertising(
        localEndpointName: _localEndpointName ?? 'Unknown',
        serviceId: SERVICE_ID,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      _errorController.add('Advertising failed: $e');
      _updateState(ConnectionState.error);
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _nearby.stopAdvertising();
      _log('Advertising stopped');
    } catch (e) {
      _log('Stop advertising error: $e', level: 900);
    }
  }

  // Connection
  Future<void> connectToPeer(String endpointId) async {
    try {
      _updateState(ConnectionState.connecting);
      _log('Initiating connection to $endpointId');
      await _nearby.requestConnection(
        localEndpointName: _localEndpointName ?? 'Unknown',
        remoteEndpointId: endpointId,
      );
    } catch (e) {
      _errorController.add('Connection request failed: $e');
      _updateState(ConnectionState.error);
    }
  }

  Future<void> acceptConnection(String endpointId) async {
    try {
      _log('Accepting connection from $endpointId');
      await _nearby.acceptConnection(
        remoteEndpointId: endpointId,
        onPayloadReceived: _onPayloadReceived,
        onPayloadTransferUpdate: _onPayloadTransferUpdate,
      );
    } catch (e) {
      _errorController.add('Accept connection failed: $e');
    }
  }

  Future<void> rejectConnection(String endpointId) async {
    try {
      await _nearby.rejectConnection(remoteEndpointId: endpointId);
      _log('Rejected connection from $endpointId');
    } catch (e) {
      _log('Reject connection error: $e', level: 900);
    }
  }

  Future<void> disconnect() async {
    if (_connectedEndpointId != null) {
      try {
        await _nearby.disconnectFromEndpoint(endpointId: _connectedEndpointId!);
        _log('Disconnected from $_connectedEndpointId');
      } catch (e) {
        _log('Disconnect error: $e', level: 900);
      }
    }
    _connectedEndpointId = null;
    _updateState(ConnectionState.disconnected);
  }

  Future<void> sendMessage(String text) async {
    if (_connectedEndpointId == null) {
      _errorController.add('Not connected to any peer');
      return;
    }

    try {
      final message = ChatMessage(text: text, isSent: true);
      final payload = Payload.fromBytes(utf8.encode(jsonEncode(message.toJson())));
      await _nearby.sendPayload(
        endpointIds: [_connectedEndpointId!],
        payload: payload,
      );
      _messageController.add(message);
      _log('Message sent: ${text.substring(0, text.length.clamp(0, 20))}...');
    } catch (e) {
      _errorController.add('Send failed: $e');
    }
  }

  // Callbacks
  void _onConnectionInitiated(String endpointId, String endpointName, String serviceId) {
    _log('Connection initiated with $endpointId ($endpointName)');
    // Auto-accept for PoC; in production, prompt user
    acceptConnection(endpointId);
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.success) {
      _log('Connected to $endpointId');
      _connectedEndpointId = endpointId;
      _localEndpointId = endpointId;
      _updateState(ConnectionState.connected);
    } else {
      _log('Connection failed: $status', level: 900);
      _errorController.add('Connection failed: $status');
      _updateState(ConnectionState.error);
    }
  }

  void _onDisconnected(String endpointId) {
    _log('Disconnected from $endpointId');
    if (_connectedEndpointId == endpointId) {
      _connectedEndpointId = null;
      _updateState(ConnectionState.disconnected);
    }
    _payloadSubscriptions.remove(endpointId);
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    try {
      if (payload.type == PayloadType.bytes) {
        final data = utf8.decode(payload.bytes!);
        final json = jsonDecode(data) as Map<String, dynamic>;
        final message = ChatMessage.fromJson(json).copyWith(isSent: false);
        _messageController.add(message);
        _log('Received message from $endpointId');
      }
    } catch (e) {
      _log('Payload decode error: $e', level: 900);
    }
  }

  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    if (update.status == PayloadTransferStatus.success) {
      _log('Payload delivered to $endpointId');
    } else if (update.status == PayloadTransferStatus.failure) {
      _log('Payload failed to $endpointId', level: 900);
    }
  }

  List<PeerDevice> getDiscoveredPeers() => _discoveredPeers.values.toList();

  void dispose() {
    stopDiscovery();
    stopAdvertising();
    disconnect();
    _discoveredPeerController.close();
    _stateController.close();
    _messageController.close();
    _errorController.close();
    _nearby.stopAllEndpoints();
  }
}