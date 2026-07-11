import 'dart:io';
import 'package:flutter/material.dart';
import 'package:zendesk_messaging_flutter/zendesk_messaging_flutter.dart';

const _iosChannelKey = String.fromEnvironment('IOS_CHANNEL_KEY');
const _androidChannelKey = String.fromEnvironment('ANDROID_CHANNEL_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final channelKey = Platform.isAndroid ? _androidChannelKey : _iosChannelKey;
  await ZendeskMessaging.initialize(channelKey: channelKey);
  // Let the app handle every tapped link itself (delivered as UrlClickedEvent)
  // instead of the SDK opening them in a browser. Use appHandlesMatching +
  // patterns for per-link granularity.
  await ZendeskMessaging.setUrlPolicy(UrlHandlingPolicy.appHandlesAll);
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
  bool _loggedIn = false;

  /// The most recent JWT, so we can transparently re-login when the SDK
  /// reports the session's token has expired (AuthenticationFailedEvent).
  String? _lastJwt;

  @override
  void initState() {
    super.initState();
    ZendeskMessaging.events.listen((event) {
      switch (event) {
        case UnreadMessageCountChangedEvent():
          setState(() => _unreadCount = event.totalUnreadCount);
        case UrlClickedEvent():
          // App is responsible for this link (per the active UrlHandlingPolicy):
          // deep-link, open with url_launcher, etc. Here we just surface it.
          _showSnack('Link tapped (${event.source}): ${event.url}');
        case AuthenticationFailedEvent():
          // The SDK's documented auth flow: on token expiry, fetch a fresh JWT
          // and log in again. Fire-and-forget — no blocking delegate.
          _handleAuthFailure();
        default:
          break;
      }
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleAuthFailure() async {
    // In a real app, request a new JWT from your backend here.
    final jwt = _lastJwt;
    if (jwt == null) {
      _showSnack('Authentication expired — please log in again.');
      setState(() => _loggedIn = false);
      return;
    }
    await ZendeskMessaging.loginUser(jwt: jwt);
    _showSnack('Session refreshed.');
  }

  Future<void> _showLoginDialog() async {
    final controller = TextEditingController();
    final jwt = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login with JWT'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Paste JWT here',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Login'),
          ),
        ],
      ),
    );

    if (jwt != null && jwt.isNotEmpty) {
      await ZendeskMessaging.loginUser(jwt: jwt);
      setState(() {
        _lastJwt = jwt;
        _loggedIn = true;
      });
    }
  }

  Future<void> _logout() async {
    await ZendeskMessaging.logoutUser();
    setState(() {
      _lastJwt = null;
      _loggedIn = false;
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
        actions: [
          if (_loggedIn)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Logout',
              onPressed: _logout,
            )
          else
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.white),
              tooltip: 'Login',
              onPressed: _showLoginDialog,
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/Zendesk_logo.svg/320px-Zendesk_logo.svg.png',
              height: 48,
              errorBuilder: (ctx, err, stack) => const SizedBox(height: 48),
            ),
            const SizedBox(height: 48),
            const Text(
              'How can we help?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _loggedIn ? 'Logged in as authenticated user.' : 'Our support team is ready for you.',
              style: const TextStyle(fontSize: 15, color: Colors.grey),
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
                      horizontal: 32,
                      vertical: 16,
                    ),
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
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ZendeskMessaging.show(fullScreen: false),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open as sheet'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF03363D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
