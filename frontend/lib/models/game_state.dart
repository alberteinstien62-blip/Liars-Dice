/// Game state model for Liar's Dice

enum GamePhase {
  waitingForPlayers,
  committing,
  bidding,
  revealing,
  roundEnd,
  gameOver,
}

GamePhase parseGamePhase(String? phase) {
  switch (phase) {
    case 'WaitingForPlayers':
      return GamePhase.waitingForPlayers;
    case 'Committing':
      return GamePhase.committing;
    case 'Bidding':
      return GamePhase.bidding;
    case 'Revealing':
      return GamePhase.revealing;
    case 'RoundEnd':
      return GamePhase.roundEnd;
    case 'GameOver':
      return GamePhase.gameOver;
    default:
      return GamePhase.waitingForPlayers;
  }
}

class Bid {
  final int quantity;
  final int face;
  final String? bidder;
  final DateTime? timestamp;

  Bid({
    required this.quantity,
    required this.face,
    this.bidder,
    this.timestamp,
  });

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid(
      quantity: json['quantity'] ?? 0,
      face: json['face']?['value'] ?? json['face'] ?? 1,
      bidder: json['bidder'],
      timestamp: json['timestamp'] != null
          ? DateTime.fromMicrosecondsSinceEpoch(json['timestamp'])
          : null,
    );
  }

  bool isHigherThan(Bid other) {
    if (quantity > other.quantity) return true;
    if (quantity == other.quantity && face > other.face) return true;
    return false;
  }

  @override
  String toString() => '$quantity x $face';
}

class GamePlayer {
  final String? chainId;
  final String name;
  final int diceCount;
  final bool eliminated;
  final bool isTurn;
  final List<int>? revealedDice;
  final bool hasCommitted;

  GamePlayer({
    this.chainId,
    required this.name,
    required this.diceCount,
    this.eliminated = false,
    this.isTurn = false,
    this.revealedDice,
    this.hasCommitted = false,
  });

  factory GamePlayer.fromJson(Map<String, dynamic> json) {
    return GamePlayer(
      chainId: json['chainId'],
      name: json['name'] ?? 'Unknown',
      diceCount: json['diceCount'] ?? 5,
      eliminated: json['eliminated'] ?? false,
      isTurn: json['isTurn'] ?? false,
      revealedDice: json['revealedDice'] != null
          ? List<int>.from(json['revealedDice']['dice'] ?? [])
          : null,
      hasCommitted: json['commitment'] != null,
    );
  }
}

class GameState {
  final int gameId;
  final List<GamePlayer> players;
  final GamePhase phase;
  final int round;
  final int currentTurn;
  final Bid? currentBid;
  final List<Bid> bidHistory;
  final String? liarCaller;
  final int totalDice;
  final String? winner;

  GameState({
    required this.gameId,
    required this.players,
    required this.phase,
    this.round = 1,
    this.currentTurn = 0,
    this.currentBid,
    this.bidHistory = const [],
    this.liarCaller,
    this.totalDice = 0,
    this.winner,
  });

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      gameId: json['gameId'] ?? 0,
      players: (json['players'] as List?)
              ?.map((p) => GamePlayer.fromJson(p))
              .toList() ??
          [],
      phase: parseGamePhase(json['phase']),
      round: json['round'] ?? 1,
      currentTurn: json['currentTurn'] ?? 0,
      currentBid:
          json['currentBid'] != null ? Bid.fromJson(json['currentBid']) : null,
      bidHistory: (json['bidHistory'] as List?)
              ?.map((b) => Bid.fromJson(b))
              .toList() ??
          [],
      liarCaller: json['liarCaller'],
      totalDice: json['totalDice'] ?? 0,
      winner: json['winner'],
    );
  }

  GamePlayer? get currentPlayer {
    if (currentTurn < players.length) {
      return players[currentTurn];
    }
    return null;
  }

  bool get isMyTurn => currentPlayer?.isTurn ?? false;
}
