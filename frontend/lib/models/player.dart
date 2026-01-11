/// Player profile model for Liar's Dice

class PlayerProfile {
  final String? chainId;
  final String name;
  final int elo;
  final int wins;
  final int losses;
  final int gamesPlayed;

  PlayerProfile({
    this.chainId,
    required this.name,
    this.elo = 1200,
    this.wins = 0,
    this.losses = 0,
    this.gamesPlayed = 0,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    // Parse nested stats from GraphQL response
    final stats = json['stats'] as Map<String, dynamic>?;
    final gamesPlayed = stats?['gamesPlayed'] ?? json['gamesPlayed'] ?? 0;
    final gamesWon = stats?['gamesWon'] ?? json['wins'] ?? 0;
    // Ensure losses are never negative
    final losses = (gamesPlayed > gamesWon) ? gamesPlayed - gamesWon : 0;

    return PlayerProfile(
      chainId: json['chainId'],
      name: json['name'] ?? 'Unknown',
      elo: json['elo'] ?? 1200,
      wins: gamesWon,
      losses: losses,
      gamesPlayed: gamesPlayed,
    );
  }

  double get winRate {
    if (gamesPlayed == 0) return 0.0;
    return wins / gamesPlayed;
  }

  String get winRateString {
    return '${(winRate * 100).toStringAsFixed(1)}%';
  }
}

class LeaderboardEntry {
  final int rank;
  final String name;
  final String chainId;
  final int elo;
  final int wins;
  final int losses;

  LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.chainId,
    required this.elo,
    this.wins = 0,
    this.losses = 0,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final gamesPlayed = json['gamesPlayed'] ?? 0;
    final gamesWon = json['gamesWon'] ?? json['wins'] ?? 0;
    // Ensure losses are never negative
    final losses = (gamesPlayed > gamesWon) ? gamesPlayed - gamesWon : 0;

    return LeaderboardEntry(
      rank: json['rank'] ?? 0,
      name: json['playerName'] ?? json['name'] ?? 'Unknown',
      chainId: json['playerId'] ?? json['chainId'] ?? '',
      elo: json['elo'] ?? 1200,
      wins: gamesWon,
      losses: losses,
    );
  }
}
