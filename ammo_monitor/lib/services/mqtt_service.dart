import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:io';

class MqttService {
  // Singleton pattern để đảm bảo chỉ có 1 kết nối duy nhất trong app
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  late MqttServerClient client;
  Function(String)? onDataReceived; // Callback để đẩy dữ liệu ra UI

  Future<void> initializeMQTTClient({
    required String server,
    required String clientId,
    required String username,
    required String password,
  }) async {
    client = MqttServerClient(server, clientId);
    client.port = 1883; // Hoặc port bạn cấu hình
    client.logging(on: true); // Bật log để debug
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic(
          'willtopic',
        ) // Tin nhắn trăn trối nếu mất kết nối đột ngột
        .withWillMessage('My Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce)
        .authenticateAs(username, password);
    client.connectionMessage = connMess;
  }

  Future<void> connect() async {
    try {
      print('MQTT: Đang kết nối...');
      await client.connect();
    } on NoConnectionException catch (e) {
      print('MQTT: Lỗi kết nối - $e');
      client.disconnect();
    } on SocketException catch (e) {
      print('MQTT: Lỗi socket - $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT: Đã kết nối thành công');
      // Sau khi kết nối thì subscribe topic
      _subscribeToTopic(
        'ammo_transport/+/telemetry',
      ); // Dấu + là wildcard, nghe tất cả xe
    } else {
      print(
        'MQTT: Kết nối thất bại - trạng thái: ${client.connectionStatus!.state}',
      );
      client.disconnect();
    }
  }

  void _subscribeToTopic(String topic) {
    print('MQTT: Đang subscribe topic $topic');
    client.subscribe(topic, MqttQos.atMostOnce);

    // Lắng nghe dữ liệu trả về
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final MqttPublishMessage recMess = c![0].payload as MqttPublishMessage;
      final String message = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );

      print('MQTT: Đã nhận data từ topic ${c[0].topic}: $message');

      // Gọi callback để đẩy dữ liệu ra ngoài cho UI xử lý
      if (onDataReceived != null) {
        onDataReceived!(message);
      }
    });
  }

  void onConnected() {
    print('MQTT: Callback - Connected');
  }

  void onDisconnected() {
    print('MQTT: Callback - Disconnected');
  }

  void onSubscribed(String topic) {
    print('MQTT: Callback - Subscribed to $topic');
  }
}
