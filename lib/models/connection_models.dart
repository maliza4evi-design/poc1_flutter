import 'package:uuid/uuid.dart';

enum ConnectionRole { advertiser, discoverer, none }

enum ConnectionState { disconnected, advertising, discovering, connecting, connected, error }

class PeerDevice {
  final String endpointId;
  final String endpointName;
  final String serviceId;
  final DateTime discoveredAt;
  final Map<String, String> metadata;

  PeerDevice({
    required this.endpointId,
    required this.endpointName,
    required this.serviceId,
    DateTime? discoveredAt,
    this.metadata = const {},
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  PeerDevice copyWith({
    String? endpointId,
    String? endpointName,
    String? serviceId,
    DateTime? discoveredAt,
    Map<String, String>? metadata,
  }) {
    return PeerDevice(
      endpointId: endpointId ?? this.endpointId,
      endpointName: endpointName ?? this.endpointName,
      serviceId: serviceId ?? this.serviceId,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() => 'PeerDevice(endpointId: $endpointId, name: $endpointName, serviceId: $serviceId)';
}

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isSent;
  final DeliveryStatus status;
  final String? localEndpointId;

  ChatMessage({
    String? id,
    required this.text,
    DateTime? timestamp,
    required this.isSent,
    this.status = DeliveryStatus.pending,
    this.localEndpointId,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    bool? isSent,
    DeliveryStatus? status,
    String? localEndpointId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isSent: isSent ?? this.isSent,
      status: status ?? this.status,
      localEndpointId: localEndpointId ?? this.localEndpointId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'isSent': isSent,
    'status': status.name,
    'localEndpointId': localEndpointId,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    text: json['text'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    isSent: json['isSent'] as bool,
    status: DeliveryStatus.values.firstWhere((e) => e.name == json['status']),
    localEndpointId: json['localEndpointId'] as String?,
  );
}

enum DeliveryStatus { pending, sent, delivered, failed }

class ConnectionLog {
  final String id;
  final DateTime timestamp;
  final String event;
  final Map<String, dynamic> data;
  final String? endpointId;

  ConnectionLog({
    String? id,
    required this.timestamp,
    required this.event,
    this.data = const {},
    this.endpointId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'event': event,
    'data': data,
    'endpointId': endpointId,
  };
}

class TestSession {
  final String id;
  final DateTime startedAt;
  DateTime? endedAt;
  final String deviceModel;
  final String androidVersion;
  final bool internetDisabled;
  int messagesSent = 0;
  int messagesReceived = 0;
  int messagesLost = 0;
  int messagesDuplicated = 0;
  int discoverySuccess = 0;
  int discoveryAttempts = 0;
  int connectionSuccess = 0;
  int connectionAttempts = 0;
  int reconnectionSuccess = 0;
  int reconnectionAttempts = 0;
  final List<ConnectionLog> logs = [];
  final List<ChatMessage> messages = [];

  TestSession({
    String? id,
    required this.deviceModel,
    required this.androidVersion,
    required this.internetDisabled,
    DateTime? startedAt,
  }) : id = id ?? const Uuid().v4(),
       startedAt = startedAt ?? DateTime.now();

  void addLog(ConnectionLog log) => logs.add(log);
  void addMessage(ChatMessage msg) => messages.add(msg);

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'deviceModel': deviceModel,
    'androidVersion': androidVersion,
    'internetDisabled': internetDisabled,
    'messagesSent': messagesSent,
    'messagesReceived': messagesReceived,
    'messagesLost': messagesLost,
    'messagesDuplicated': messagesDuplicated,
    'discoverySuccess': discoverySuccess,
    'discoveryAttempts': discoveryAttempts,
    'connectionSuccess': connectionSuccess,
    'connectionAttempts': connectionAttempts,
    'reconnectionSuccess': reconnectionSuccess,
    'reconnectionAttempts': reconnectionAttempts,
    'logs': logs.map((e) => e.toJson()).toList(),
    'messages': messages.map((e) => e.toJson()).toList(),
  };
}