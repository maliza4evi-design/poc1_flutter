import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/connection_models.dart';
import '../services/nearby_service.dart';
import '../utils/logger.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  
  String _localName = '';
  bool _initialized = false;
  bool _permissionsRequested = false;
  final List<ChatMessage> _messages = [];
  final List<ConnectionLog> _logs = [];
  StreamSubscription? _peerSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _messageSub;
  StreamSubscription? _errorSub;

  @override
  void initState() {
    super.initState();
    _nameController.text = 'User_${DateTime.now().millisecondsSinceEpoch % 10000}';
    _requestPermissions();
  }

  @override
  void dispose() {
    _peerSub?.cancel();
    _stateSub?.cancel();
    _messageSub?.cancel();
    _errorSub?.cancel();
    _nameController.dispose();
    _messageController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;
    
    final statuses = await [
      Permission.location,
      Permission.nearbyWifiDevices,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ].request();
    
    final allGranted = statuses.values.every((s) => s.isGranted);
    if (allGranted && mounted) {
      _initializeService();
    } else if (mounted) {
      _showSnackBar('Permissions required for Nearby Connections', error: true);
    }
  }

  void _initializeService() {
    final service = context.read<NearbyService>();
    service.initialize(localName: _nameController.text).then((success) {
      if (success && mounted) {
        setState(() => _initialized = true);
        _subscribeToStreams();
        _startAdvertisingAndDiscovery();
      } else if (mounted) {
        _showSnackBar('Failed to initialize Nearby Connections', error: true);
      }
    });
  }

  void _subscribeToStreams() {
    final service = context.read<NearbyService>();
    _peerSub = service.discoveredPeers.listen(_onPeerDiscovered);
    _stateSub = service.stateChanges.listen(_onStateChanged);
    _messageSub = service.messages.listen(_onMessageReceived);
    _errorSub = service.errors.listen(_onError);
  }

  void _startAdvertisingAndDiscovery() {
    final service = context.read<NearbyService>();
    service.startAdvertising();
    service.startDiscovery();
  }

  void _onPeerDiscovered(PeerDevice peer) {
    if (mounted) setState(() {});
  }

  void _onStateChanged(ConnectionState state) {
    if (mounted) setState(() {});
    _addLog('State changed: $state');
  }

  void _onMessageReceived(ChatMessage message) {
    if (mounted) {
      setState(() => _messages.add(message));
      _scrollToBottom();
    }
  }

  void _onError(String error) {
    if (mounted) {
      _showSnackBar(error, error: true);
      _addLog('Error: $error');
    }
  }

  void _addLog(String event, {Map<String, dynamic> data = const {}, String? endpointId}) {
    final log = ConnectionLog(
      timestamp: DateTime.now(),
      event: event,
      data: data,
      endpointId: endpointId,
    );
    if (mounted) setState(() => _logs.add(log));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messagesScrollController.hasClients) {
        _messagesScrollController.animateTo(
          _messagesScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
        duration: Duration(seconds: error ? 5 : 3),
      ),
    );
  }

  Future<void> _connectToPeer(PeerDevice peer) async {
    final service = context.read<NearbyService>();
    _addLog('Connecting to ${peer.endpointName}', endpointId: peer.endpointId);
    await service.connectToPeer(peer.endpointId);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final service = context.read<NearbyService>();
    if (service.currentState != ConnectionState.connected) {
      _showSnackBar('Not connected to any peer', error: true);
      return;
    }

    _messageController.clear();
    await service.sendMessage(text);
  }

  Future<void> _disconnect() async {
    final service = context.read<NearbyService>();
    await service.disconnect();
    if (mounted) {
      setState(() => _messages.clear());
      _addLog('Disconnected by user');
    }
  }

  Future<void> _exportLogs() async {
    final service = context.read<NearbyService>();
    // In real implementation, save to file via path_provider
    _addLog('Logs exported', data: {
      'total_logs': _logs.length,
      'total_messages': _messages.length,
    });
    _showSnackBar('Logs exported (check debug output)');
    // Print to console for now
    for (final log in _logs) {
      print('LOG: ${log.toJson()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NearbyService>();
    final peers = service.getDiscoveredPeers();
    final state = service.currentState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PoC-1A Direct Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportLogs,
            tooltip: 'Export Logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              service.startDiscovery();
              service.startAdvertising();
            },
            tooltip: 'Refresh Discovery',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: _getStateColor(state).withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  _getStateIcon(state),
                  color: _getStateColor(state),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Status: ${_getStateText(state)}',
                    style: TextStyle(
                      color: _getStateColor(state),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (state == ConnectionState.connected)
                  TextButton.icon(
                    icon: const Icon(Icons.link_off, size: 18),
                    label: const Text('Disconnect'),
                    onPressed: _disconnect,
                  ),
              ],
            ),
          ),

          // Local Name Setup
          if (!_initialized)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        border: OutlineInputBorder(),
                        hintText: 'Enter display name',
                      ),
                      onSubmitted: (_) => _initializeService(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Initialize'),
                    onPressed: _initializeService,
                  ),
                ],
              ),

          // Discovered Peers
          if (_initialized && peers.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Nearby Devices (${peers.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: peers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final peer = peers[index];
                  return SizedBox(
                    width: 200,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              peer.endpointName,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${peer.endpointId.substring(0, 8)}...',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Discovered: ${_formatTime(peer.discoveredAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const Spacer(),
                            if (state != ConnectionState.connected)
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () => _connectToPeer(peer),
                                  child: const Text('Connect'),
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
          ],

          // Messages Area
          const Divider(height: 1),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          state == ConnectionState.connected
                              ? Icons.chat_bubble_outline
                              : Icons.wifi_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state == ConnectionState.connected
                              ? 'No messages yet. Start chatting!'
                              : 'Connect to a peer to start messaging',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _messagesScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Align(
                        alignment: msg.isSent ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: msg.isSent
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg.text,
                                style: TextStyle(
                                  color: msg.isSent
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(msg.timestamp),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: msg.isSent
                                          ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  if (msg.isSent) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      msg.status == DeliveryStatus.delivered
                                          ? Icons.done_all
                                          : Icons.done,
                                      size: 14,
                                      color: msg.status == DeliveryStatus.delivered
                                          ? Colors.lightBlueAccent
                                          : Colors.grey,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Message Input
          if (_initialized && state == ConnectionState.connected)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('Send'),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  Color _getStateColor(ConnectionState state) {
    switch (state) {
      case ConnectionState.connected:
        return Colors.green;
      case ConnectionState.connecting:
        return Colors.orange;
      case ConnectionState.advertising:
      case ConnectionState.discovering:
        return Colors.blue;
      case ConnectionState.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStateIcon(ConnectionState state) {
    switch (state) {
      case ConnectionState.connected:
        return Icons.wifi;
      case ConnectionState.connecting:
        return Icons.sync;
      case ConnectionState.advertising:
        return Icons.broadcast_on_personal;
      case ConnectionState.discovering:
        return Icons.search;
      case ConnectionState.error:
        return Icons.error;
      default:
        return Icons.wifi_off;
    }
  }

  String _getStateText(ConnectionState state) {
    switch (state) {
      case ConnectionState.connected:
        return 'Connected';
      case ConnectionState.connecting:
        return 'Connecting...';
      case ConnectionState.advertising:
        return 'Advertising';
      case ConnectionState.discovering:
        return 'Discovering...';
      case ConnectionState.error:
        return 'Error';
      default:
        return 'Disconnected';
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}.${dt.millisecond.toString().padLeft(3, '0')}';
  }
}