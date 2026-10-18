import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:poc1_flutter/models/connection_models.dart';
import 'package:poc1_flutter/services/nearby_service.dart';

@GenerateMocks([Nearby])
void main() {
  group('Connection Models Tests', () {
    test('PeerDevice creation and copyWith', () {
      final peer = PeerDevice(
        endpointId: 'test-id',
        endpointName: 'Test Device',
        serviceId: 'test-service',
      );
      
      expect(peer.endpointId, 'test-id');
      expect(peer.endpointName, 'Test Device');
      expect(peer.serviceId, 'test-service');
      expect(peer.metadata, isEmpty);
      
      final updated = peer.copyWith(endpointName: 'Updated Name');
      expect(updated.endpointName, 'Updated Name');
      expect(updated.endpointId, 'test-id');
    });

    test('ChatMessage creation and serialization', () {
      final msg = ChatMessage(
        text: 'Hello World',
        isSent: true,
        status: DeliveryStatus.sent,
      );
      
      expect(msg.text, 'Hello World');
      expect(msg.isSent, true);
      expect(msg.status, DeliveryStatus.sent);
      expect(msg.id, isNotEmpty);
      
      final json = msg.toJson();
      expect(json['text'], 'Hello World');
      expect(json['isSent'], true);
      expect(json['status'], 'sent');
      
      final fromJson = ChatMessage.fromJson(json);
      expect(fromJson.text, msg.text);
      expect(fromJson.isSent, msg.isSent);
      expect(fromJson.id, msg.id);
    });

    test('ChatMessage copyWith', () {
      final msg = ChatMessage(text: 'Original', isSent: false);
      final updated = msg.copyWith(text: 'Updated', status: DeliveryStatus.delivered);
      
      expect(updated.text, 'Updated');
      expect(updated.isSent, false);
      expect(updated.status, DeliveryStatus.delivered);
      expect(updated.id, msg.id);
    });

    test('ConnectionLog serialization', () {
      final log = ConnectionLog(
        timestamp: DateTime.now(),
        event: 'Test Event',
        data: {'key': 'value'},
        endpointId: 'endpoint-123',
      );
      
      final json = log.toJson();
      expect(json['event'], 'Test Event');
      expect(json['data']['key'], 'value');
      expect(json['endpointId'], 'endpoint-123');
    });

    test('TestSession tracking', () {
      final session = TestSession(
        deviceModel: 'Pixel 6a',
        androidVersion: '14',
        internetDisabled: true,
      );
      
      expect(session.deviceModel, 'Pixel 6a');
      expect(session.androidVersion, '14');
      expect(session.internetDisabled, true);
      expect(session.messagesSent, 0);
      expect(session.messagesReceived, 0);
      
      session.messagesSent++;
      session.messagesReceived += 2;
      
      expect(session.messagesSent, 1);
      expect(session.messagesReceived, 2);
      
      final json = session.toJson();
      expect(json['messagesSent'], 1);
      expect(json['messagesReceived'], 2);
    });
  });

  group('ConnectionState Enum', () {
    test('All states present', () {
      expect(ConnectionState.values.length, 6);
      expect(ConnectionState.values, containsAll([
        ConnectionState.disconnected,
        ConnectionState.advertising,
        ConnectionState.discovering,
        ConnectionState.connecting,
        ConnectionState.connected,
        ConnectionState.error,
      ]));
    });
  });

  group('DeliveryStatus Enum', () {
    test('All statuses present', () {
      expect(DeliveryStatus.values.length, 4);
      expect(DeliveryStatus.values, containsAll([
        DeliveryStatus.pending,
        DeliveryStatus.sent,
        DeliveryStatus.delivered,
        DeliveryStatus.failed,
      ]));
    });
  });
}