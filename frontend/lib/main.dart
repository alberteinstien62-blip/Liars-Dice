import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'services/game_service.dart';
import 'services/config_service.dart';
import 'screens/lobby_screen.dart';
import 'screens/game_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/reveal_screen.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForFlutter();

  // Set system UI style for immersive gaming experience
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.backgroundDark,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // ✅ FIX: Add error handling for config loading
  try {
    final config = await ConfigService.loadConfig();
    runApp(LiarsDiceApp(config: config));
  } catch (e) {
    runApp(ConfigErrorApp(error: e.toString()));
  }
}

/// Error screen shown when config.json fails to load
class ConfigErrorApp extends StatelessWidget {
  final String error;

  const ConfigErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Liar's Dice - Configuration Error",
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Configuration Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please ensure config.json exists in the assets folder\nwith valid Linera chain configuration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LiarsDiceApp extends StatelessWidget {
  final AppConfig config;

  const LiarsDiceApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final httpLink = HttpLink(
      '${config.nodeServiceURL}/chains/${config.userChain}/applications/${config.liarsDiceAppId}',
    );

    final client = ValueNotifier<GraphQLClient>(
      GraphQLClient(
        link: httpLink,
        cache: GraphQLCache(store: HiveStore()),
      ),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => GameService(config: config),
        ),
        Provider.value(value: config),
      ],
      child: GraphQLProvider(
        client: client,
        child: MaterialApp(
          title: "Liar's Dice",
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          initialRoute: '/',
          routes: {
            '/': (context) => const LobbyScreen(),
            '/game': (context) => const GameScreen(),
            '/leaderboard': (context) => const LeaderboardScreen(),
          },
        ),
      ),
    );
  }
}
