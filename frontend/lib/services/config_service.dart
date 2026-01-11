import 'dart:convert';
import 'package:flutter/services.dart';

class AppConfig {
  final String nodeServiceURL;
  final String liarsDiceAppId;
  final String bankrollAppId;
  final String masterChain;
  final String lobbyChain;
  final String userChain;

  AppConfig({
    required this.nodeServiceURL,
    required this.liarsDiceAppId,
    required this.bankrollAppId,
    required this.masterChain,
    required this.lobbyChain,
    required this.userChain,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      nodeServiceURL: json['nodeServiceURL'] ?? 'http://localhost:8082',
      liarsDiceAppId: json['liarsDiceAppId'] ?? '',
      bankrollAppId: json['bankrollAppId'] ?? '',
      masterChain: json['masterChain'] ?? '',
      lobbyChain: json['lobbyChain'] ?? '',
      userChain: json['userChain'] ?? '',
    );
  }

  String get graphqlEndpoint =>
      '$nodeServiceURL/chains/$userChain/applications/$liarsDiceAppId';

  String get bankrollEndpoint =>
      '$nodeServiceURL/chains/$userChain/applications/$bankrollAppId';
}

class ConfigService {
  static Future<AppConfig> loadConfig() async {
    try {
      final jsonString = await rootBundle.loadString('config.json');
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final config = AppConfig.fromJson(json);

      // Validate required fields are not empty
      if (config.liarsDiceAppId.isEmpty) {
        throw Exception('liarsDiceAppId is required in config.json');
      }
      if (config.bankrollAppId.isEmpty) {
        throw Exception('bankrollAppId is required in config.json');
      }
      if (config.masterChain.isEmpty) {
        throw Exception('masterChain is required in config.json');
      }
      if (config.lobbyChain.isEmpty) {
        throw Exception('lobbyChain is required in config.json');
      }
      if (config.userChain.isEmpty) {
        throw Exception('userChain is required in config.json');
      }

      return config;
    } catch (e) {
      // Log and rethrow with clear message
      print('ERROR: Failed to load config.json: $e');
      print('');
      print('Please ensure config.json exists in the assets folder with:');
      print('  - nodeServiceURL: Linera node URL');
      print('  - liarsDiceAppId: Application ID');
      print('  - bankrollAppId: Bankroll application ID');
      print('  - masterChain: Master chain ID');
      print('  - lobbyChain: Lobby chain ID');
      print('  - userChain: User chain ID');
      rethrow;
    }
  }
}
