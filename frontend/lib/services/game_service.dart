import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config_service.dart';
import '../models/game_state.dart';
import '../models/player.dart';

class GameService extends ChangeNotifier {
  final AppConfig config;

  PlayerProfile? _profile;
  GameState? _gameState;
  List<int>? _myDice;
  Uint8List? _mySalt;
  bool _isLoading = false;
  String? _error;
  int _queueCount = 0;
  bool _inQueue = false;

  // Polling for real-time updates
  Timer? _pollTimer;
  Timer? _queuePollTimer;
  static const Duration _pollInterval = Duration(seconds: 2);
  static const Duration _queuePollInterval = Duration(seconds: 3);

  // ✅ FIX: HTTP request timeout and retry configuration
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const int _maxRetries = 3;
  bool _requestInProgress = false;  // Prevents overlapping requests

  // ✅ FIX: Connection status tracking for SyncIndicator
  bool _isConnected = true;
  bool _isSyncing = false;
  DateTime? _lastSuccessfulRequest;

  GameService({required this.config});

  /// Start polling for game state updates
  void startGamePolling() {
    stopGamePolling();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      await loadGameState();
    });
  }

  /// Stop polling for game state updates
  void stopGamePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Start polling for queue/matchmaking updates
  void startQueuePolling() {
    stopQueuePolling();
    _queuePollTimer = Timer.periodic(_queuePollInterval, (_) async {
      await loadQueueCount();
      // Check if we got matched
      if (_inQueue) {
        await loadGameState();
        if (_gameState != null) {
          _inQueue = false;
          stopQueuePolling();
          startGamePolling();
        }
      }
    });
  }

  /// Stop polling for queue updates
  void stopQueuePolling() {
    _queuePollTimer?.cancel();
    _queuePollTimer = null;
  }

  @override
  void dispose() {
    stopGamePolling();
    stopQueuePolling();
    super.dispose();
  }

  /// Escape special characters in a string for safe GraphQL interpolation
  static String _escapeGraphQL(String input) {
    return input
        .replaceAll('\\', '\\\\')  // Escape backslashes first
        .replaceAll('"', '\\"')     // Escape double quotes
        .replaceAll('\n', '\\n')    // Escape newlines
        .replaceAll('\r', '\\r')    // Escape carriage returns
        .replaceAll('\t', '\\t');   // Escape tabs
  }

  // Getters
  PlayerProfile? get profile => _profile;
  GameState? get gameState => _gameState;
  List<int>? get myDice => _myDice;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get queueCount => _queueCount;
  bool get inQueue => _inQueue;
  bool get isInGame => _gameState != null;

  // ✅ FIX: Connection status getters for SyncIndicator
  bool get isConnected => _isConnected;
  bool get isSyncing => _isSyncing;
  String? get lastSyncTime => _lastSuccessfulRequest != null
      ? '${_lastSuccessfulRequest!.hour.toString().padLeft(2, '0')}:${_lastSuccessfulRequest!.minute.toString().padLeft(2, '0')}:${_lastSuccessfulRequest!.second.toString().padLeft(2, '0')}'
      : null;

  // GraphQL helper with timeout, retry, and request locking
  Future<Map<String, dynamic>?> _executeGraphQL(String query,
      {Map<String, dynamic>? variables, bool skipLock = false}) async {
    // ✅ FIX: Prevent overlapping requests (race condition fix)
    if (!skipLock && _requestInProgress) {
      return null;  // Skip if another request is in progress
    }

    if (!skipLock) _requestInProgress = true;
    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _executeGraphQLWithRetry(query, variables: variables);
      if (result != null) {
        // ✅ FIX: Update connection status on success
        _isConnected = true;
        _lastSuccessfulRequest = DateTime.now();
      }
      return result;
    } catch (e) {
      // ✅ FIX: Update connection status on failure
      _isConnected = false;
      rethrow;
    } finally {
      if (!skipLock) _requestInProgress = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Execute GraphQL with exponential backoff retry
  Future<Map<String, dynamic>?> _executeGraphQLWithRetry(String query,
      {Map<String, dynamic>? variables, int attempt = 1}) async {
    try {
      // ✅ FIX: Add timeout to prevent indefinite hangs
      final response = await http.post(
        Uri.parse(config.graphqlEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          if (variables != null) 'variables': variables,
        }),
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['errors'] != null) {
          _error = data['errors'][0]['message'];
          return null;
        }
        return data['data'];
      } else if (response.statusCode >= 500 && attempt < _maxRetries) {
        // ✅ FIX: Retry on server errors with exponential backoff
        await Future.delayed(Duration(milliseconds: 100 * (1 << attempt)));
        return _executeGraphQLWithRetry(query, variables: variables, attempt: attempt + 1);
      } else {
        _error = 'HTTP ${response.statusCode}';
        return null;
      }
    } on TimeoutException {
      if (attempt < _maxRetries) {
        // Retry on timeout with exponential backoff
        await Future.delayed(Duration(milliseconds: 100 * (1 << attempt)));
        return _executeGraphQLWithRetry(query, variables: variables, attempt: attempt + 1);
      }
      _error = 'Request timed out after $_maxRetries attempts';
      _isConnected = false;  // ✅ FIX: Mark as disconnected on final timeout
      return null;
    } catch (e) {
      if (attempt < _maxRetries) {
        // Retry on network errors with exponential backoff
        await Future.delayed(Duration(milliseconds: 100 * (1 << attempt)));
        return _executeGraphQLWithRetry(query, variables: variables, attempt: attempt + 1);
      }
      _error = e.toString();
      _isConnected = false;  // ✅ FIX: Mark as disconnected on final error
      return null;
    }
  }

  // Profile operations
  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    final data = await _executeGraphQL('''
      query {
        getUserProfile {
          chainId
          name
          elo
          stats {
            gamesPlayed
            gamesWon
            roundsPlayed
            roundsWon
          }
        }
      }
    ''');

    if (data != null && data['getUserProfile'] != null) {
      _profile = PlayerProfile.fromJson(data['getUserProfile']);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> setProfile(String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Escape special characters to prevent GraphQL injection
    final escapedName = _escapeGraphQL(name);

    final data = await _executeGraphQL('''
      mutation {
        setProfile(name: "$escapedName")
      }
    ''');

    _isLoading = false;

    if (data != null) {
      await loadProfile();
      return true;
    }

    notifyListeners();
    return false;
  }

  /// Initialize connection to lobby chain
  /// Must be called before findMatch will work
  Future<bool> initialSetup() async {
    try {
      final data = await _executeGraphQL('''
        mutation {
          initialSetup
        }
      ''');

      if (data != null) {
        print('InitialSetup completed successfully');
        return true;
      }

      print('InitialSetup failed - no data returned');
      return false;
    } catch (e) {
      print('InitialSetup error: $e');
      _error = 'Failed to initialize: $e';
      notifyListeners();
      return false;
    }
  }

  // Matchmaking
  Future<void> loadQueueCount() async {
    final data = await _executeGraphQL('''
      query {
        getQueueCount
      }
    ''');

    if (data != null) {
      _queueCount = data['getQueueCount'] ?? 0;
      notifyListeners();
    }
  }

  Future<bool> findMatch() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Check if we have lobby connection first
    final lobbyChain = await _executeGraphQL('''
      query {
        getLobbyChain
      }
    ''');

    if (lobbyChain == null || lobbyChain['getLobbyChain'] == null) {
      _error = 'Not connected to lobby. Please restart the app.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final data = await _executeGraphQL('''
      mutation {
        findMatch
      }
    ''');

    _isLoading = false;

    if (data != null) {
      _inQueue = true;
      startQueuePolling(); // Start polling for match updates
      notifyListeners();
      return true;
    }

    notifyListeners();
    return false;
  }

  Future<bool> cancelMatch() async {
    final data = await _executeGraphQL('''
      mutation {
        cancelMatch
      }
    ''');

    if (data != null) {
      _inQueue = false;
      stopQueuePolling(); // Stop polling when cancelling
      notifyListeners();
      return true;
    }
    return false;
  }

  // Game state
  Future<void> loadGameState() async {
    final data = await _executeGraphQL('''
      query {
        getGameState {
          gameId
          players {
            chainId
            name
            diceCount
            eliminated
            isTurn
            commitment { hash revealed }
            revealedDice { dice count }
          }
          phase
          round
          currentTurn
          currentBid { quantity face bidder }
          bidHistory { quantity face bidder }
          liarCaller
          totalDice
          winner
        }
      }
    ''');

    if (data != null && data['getGameState'] != null) {
      _gameState = GameState.fromJson(data['getGameState']);
      _inQueue = false;

      // ✅ FIX: Also load user dice from backend for display
      // Backend auto-generates dice, so we need to query them
      await loadUserDice();

      notifyListeners();
    }
  }

  // ============================================
  // Dice operations - UPDATED: Backend now auto-handles dice
  // ============================================

  /// Load user's dice from backend (generated by backend in GameStarted/RoundResult)
  /// Frontend no longer generates dice - backend handles commit-reveal automatically
  Future<void> loadUserDice() async {
    final data = await _executeGraphQL('''
      query {
        getUserDice {
          dice
          count
        }
      }
    ''');

    if (data != null && data['getUserDice'] != null) {
      final diceData = data['getUserDice'];
      if (diceData['dice'] != null) {
        _myDice = (diceData['dice'] as List).map((d) {
          // Handle both direct value and {value: X} format
          if (d is int) return d;
          if (d is Map && d.containsKey('value')) return d['value'] as int;
          return d as int;
        }).toList();
        notifyListeners();
      }
    }
  }

  /// DEPRECATED: Backend now auto-generates dice in GameStarted handler
  /// Kept for compatibility but marked as legacy
  void rollDice() {
    // NOTE: This is now a NO-OP. Backend generates dice automatically.
    // Use loadUserDice() to get backend-generated dice for display.
    print('[LEGACY] rollDice() called - backend now handles dice generation');
    // Don't generate client-side dice anymore to avoid mismatch
  }

  /// DEPRECATED: Backend now creates commitment automatically
  Uint8List _createCommitment() {
    if (_myDice == null || _mySalt == null) {
      throw Exception('Dice not available - wait for backend to generate');
    }
    final diceBytes = Uint8List.fromList(_myDice!);
    final combined = Uint8List(diceBytes.length + _mySalt!.length);
    combined.setAll(0, diceBytes);
    combined.setAll(diceBytes.length, _mySalt!);
    return Uint8List.fromList(sha256.convert(combined).bytes);
  }

  /// DEPRECATED: Backend now auto-commits in GameStarted handler
  /// This is kept for manual override but should not be used normally
  Future<bool> commitDice() async {
    // NOTE: Backend auto-commits when receiving GameStarted message
    // This mutation is only needed if manual commit is required
    print('[LEGACY] commitDice() called - backend now handles commit automatically');

    // If we have locally generated dice, try to commit (legacy path)
    if (_myDice != null && _mySalt != null) {
      final commitment = _createCommitment();
      final commitmentHex =
          commitment.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

      final data = await _executeGraphQL('''
        mutation {
          commitDice(commitment: "$commitmentHex")
        }
      ''');
      return data != null;
    }

    // No dice to commit - backend should have auto-committed
    return true;
  }

  /// DEPRECATED: Backend now auto-reveals in LiarCalled handler
  /// This is kept for manual override but should not be used normally
  Future<bool> revealDice() async {
    // NOTE: Backend auto-reveals when receiving LiarCalled message
    // This mutation is only needed if manual reveal is required
    print('[LEGACY] revealDice() called - backend now handles reveal automatically');

    // If we have locally generated dice, try to reveal (legacy path)
    if (_myDice != null && _mySalt != null) {
      final diceJson = jsonEncode(_myDice);
      final saltHex =
          _mySalt!.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

      final data = await _executeGraphQL('''
        mutation {
          revealDice(dice: $diceJson, salt: "$saltHex")
        }
      ''');
      return data != null;
    }

    // No dice to reveal - backend should have auto-revealed
    return true;
  }

  // Bidding
  Future<bool> makeBid(int quantity, int face) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final data = await _executeGraphQL('''
      mutation {
        makeBid(quantity: $quantity, face: $face)
      }
    ''');

    _isLoading = false;

    if (data != null) {
      await loadGameState();
      return true;
    }

    notifyListeners();
    return false;
  }

  Future<bool> callLiar() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final data = await _executeGraphQL('''
      mutation {
        callLiar
      }
    ''');

    _isLoading = false;

    if (data != null) {
      await loadGameState();
      return true;
    }

    notifyListeners();
    return false;
  }

  // Leaderboard
  Future<List<LeaderboardEntry>> loadLeaderboard() async {
    final data = await _executeGraphQL('''
      query {
        getLeaderboard {
          rank
          playerName
          playerId
          elo
          gamesPlayed
          gamesWon
        }
      }
    ''');

    if (data != null && data['getLeaderboard'] != null) {
      return (data['getLeaderboard'] as List)
          .map((e) => LeaderboardEntry.fromJson(e))
          .toList();
    }
    return [];
  }

  // Cleanup
  void clearGame() {
    stopGamePolling();
    stopQueuePolling();
    _gameState = null;
    _myDice = null;
    _mySalt = null;
    _inQueue = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
