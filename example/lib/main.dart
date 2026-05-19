import 'package:flutter/material.dart';
import 'package:zendesk_messaging_flutter/zendesk_messaging_flutter.dart';

// dmakarau — anonymous access, confirmed working with ZendeskSDKMessaging 2.38.1
const _channelKey =
    'eyJzZXR0aW5nc191cmwiOiJodHRwczovL3ozbmRlbmlzbWFrYXJhdS56ZW5kZXNrLmNvbS9tb2JpbGVfc2RrX2FwaS9zZXR0aW5ncy8wMUZINTlBRTk1N0FLMERQNlZBV0dFR0ZKUC5qc29uIn0=';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ZendeskMessaging.initialize(channelKey: _channelKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zendesk Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF03363D)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    ZendeskMessaging.events.listen((event) {
      if (event['type'] == 'unreadMessageCountChanged') {
        setState(() => _unreadCount = event['count'] as int);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF03363D),
        title: const Text(
          'Acme Support',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/Zendesk_logo.svg/320px-Zendesk_logo.svg.png',
              height: 48,
              errorBuilder: (_, __, ___) => const SizedBox(height: 48),
            ),
            const SizedBox(height: 48),
            const Text(
              'How can we help?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Our support team is ready for you.',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            Stack(
              clipBehavior: Clip.none,
              children: [
                ElevatedButton.icon(
                  onPressed: () => ZendeskMessaging.show(),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Contact Support'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF03363D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_unreadCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
