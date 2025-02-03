import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'dart:convert';

const String deviceName = "Multimedia";
final Guid serviceUuid = Guid("55c1ef40-6155-47cf-929a-c994c915ca22");
final Guid characteristicUuid = Guid("55c1ef41-6155-47cf-929a-c994c915ca22");

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Now Playing Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _currentSong;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  String _connectionStatus = "🔄 Searching for device...";
  String track = "No track";

  @override
  void initState() {
    super.initState();
    _startListening();
    _connectToBLEDevice();
  }

  Future<void> _requestPermission() async {
    try {
      final bool isGranted = await NotificationListenerService.isPermissionGranted();
      if (!isGranted) {
        await NotificationListenerService.requestPermission();
        final bool isGranted = await NotificationListenerService.isPermissionGranted();
        if (isGranted) {
          debugPrint("Permission granted after request.");
        } else {
          debugPrint("Permission still not granted!");
        }
      } else {
        debugPrint("Permission already granted.");
      }
    } catch (e) {
      debugPrint("Error requesting permission: $e");
    }
  }

  void _startListening() {
    NotificationListenerService.notificationsStream.listen((event) {
      if (event.packageName?.contains("spotify") == true ||
          event.packageName?.contains("music") == true) {
        track = "${event.title} - ${event.content}";
        track = track.replaceAll(RegExp(r'[ⓘ️]'), '').trim(); // Убираем значок ⓘ
        setState(() {
          _currentSong = track;
        });
        _sendTrackName(track);
      }
    });
  }

  Future<void> _connectToBLEDevice() async {
    setState(() {
      _connectionStatus = "🔄 Searching for device...";
    });

    // Если устройство уже подключено, не начинаем новое сканирование.
    if (_connectedDevice != null) return;

    // Начинаем сканирование
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    // Слушаем результаты сканирования
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name == deviceName) {
          setState(() {
            _connectionStatus = "🔗 Connecting to device...";
          });

          try {
            await r.device.connect();
          } catch (e) {
            debugPrint("Ошибка подключения: $e");
            continue;
          }
          FlutterBluePlus.stopScan();
          _connectedDevice = r.device;
          setState(() {
            _connectionStatus = "✅ Connected to $deviceName";
          });
          await _discoverServices();
          _sendTrackName(track);
          _monitorDeviceConnection(); // Подписываемся на изменения состояния устройства
          break;
        }
      }
    });
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;
    List<BluetoothService> services = await _connectedDevice!.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid == serviceUuid) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.uuid == characteristicUuid) {
            _writeCharacteristic = characteristic;
            debugPrint("Characteristic found: ${characteristic.uuid}");
            break;
          }
        }
      }
    }
  }

  /// Отправка названия трека через BLE
  Future<void> _sendTrackName(String trackName) async {
    if (_writeCharacteristic != null) {
      List<int> bytes = utf8.encode(trackName);
      await _writeCharacteristic!.write(bytes);
      debugPrint("Sent track: $trackName");
    }
  }

  /// Подписка на изменения состояния подключения устройства.
  /// Если устройство отсоединяется, запускается логика переподключения.
  void _monitorDeviceConnection() {
    _connectedDevice?.state.listen((state) {
      debugPrint("Device state: $state");
      if (state == BluetoothConnectionState.disconnected) {
        setState(() {
          _connectionStatus = "❌ Disconnected. Reconnecting...";
          _writeCharacteristic = null;
          _connectedDevice = null;
        });
        // Можно добавить небольшую задержку перед переподключением
        Future.delayed(const Duration(seconds: 2), () {
          _connectToBLEDevice();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing Tracker')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Now Playing:'),
            Text(
              _currentSong ?? 'No song detected',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text(
              _connectionStatus,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blue),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _requestPermission,
              child: const Text('Request Permission'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _connectToBLEDevice,
              child: const Text('Reconnect Bluetooth'),
            ),
          ],
        ),
      ),
    );
  }
}
