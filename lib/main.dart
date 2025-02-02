import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

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

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _startListening();
  }

  /// Запрашиваем разрешение у пользователя
  Future<void> _requestPermission() async {
    bool isGranted = await NotificationListenerService.requestPermission();
    if (!isGranted) {
      debugPrint("Permission not granted!");
    }
  }

  /// Начинаем слушать уведомления
  void _startListening() {
    NotificationListenerService.notificationsStream.listen((event) {
      if (event.packageName?.contains("spotify") == true ||
          event.packageName?.contains("music") == true) {
        setState(() {
          _currentSong = "${event.title} - ${event.content}";
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
            ElevatedButton(
              onPressed: _requestPermission,
              child: const Text('Request Permission'),
            ),
          ],
        ),
      ),
    );
  }
}
