import 'dart:math';

import 'package:mtg_tournament_engine/tournament_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Standings & tiebreakers', () {
    // Hand-computed reference scenario (4 players, 2 rounds):
    //   R1: A beats B 2-0 ; C beats D 2-1
    //   R2: A beats C 2-1 ; B beats D 2-0
    //
    // Expected match points: A=6, B=3, C=3, D=0
    // Expected GW%: A=0.80, B=0.50, C=0.50, D=0.33 (floored from 0.20)
    // Expected MWP: A=1.0, B=0.5, C=0.5, D=0.33 (floored from 0)
    // Expected OMW%: A=0.50, B=0.665, C=0.665, D=0.50
    final players = const [
      Player(id: 'A', name: 'Alice'),
      Player(id: 'B', name: 'Bob'),
      Player(id: 'C', name: 'Carol'),
      Player(id: 'D', name: 'Dave'),
    ];
    final rounds = [
      Round(number: 1, matches: [
        Match.pairing('A', 'B')
            .withResult(const MatchResult(player1GameWins: 2, player2GameWins: 0)),
        Match.pairing('C', 'D')
            .withResult(const MatchResult(player1GameWins: 2, player2GameWins: 1)),
      ]),
      Round(number: 2, matches: [
        Match.pairing('A', 'C')
            .withResult(const MatchResult(player1GameWins: 2, player2GameWins: 1)),
        Match.pairing('B', 'D')
            .withResult(const MatchResult(player1GameWins: 2, player2GameWins: 0)),
      ]),
    ];

    final standings = StandingsCalculator.compute(players, rounds);
    Standing byId(String id) => standings.firstWhere((s) => s.player.id == id);

    test('match points are correct', () {
      expect(byId('A').matchPoints, 6);
      expect(byId('B').matchPoints, 3);
      expect(byId('C').matchPoints, 3);
      expect(byId('D').matchPoints, 0);
    });

    test('ranks: A first, D last', () {
      expect(byId('A').rank, 1);
      expect(byId('D').rank, 4);
    });

    test('game-win percentage with 33% floor', () {
      expect(byId('A').gameWinPct, closeTo(0.80, 1e-9));
      expect(byId('B').gameWinPct, closeTo(0.50, 1e-9));
      expect(byId('C').gameWinPct, closeTo(0.50, 1e-9));
      expect(byId('D').gameWinPct, closeTo(0.33, 1e-9)); // floored
    });

    test('match-win percentage with 33% floor', () {
      expect(byId('A').matchWinPct, closeTo(1.0, 1e-9));
      expect(byId('D').matchWinPct, closeTo(0.33, 1e-9)); // floored
    });

    test('opponents match-win percentage (OMW%)', () {
      expect(byId('A').oppMatchWinPct, closeTo(0.50, 1e-9));
      expect(byId('B').oppMatchWinPct, closeTo((1.0 + 0.33) / 2, 1e-9));
      expect(byId('C').oppMatchWinPct, closeTo((0.33 + 1.0) / 2, 1e-9));
      expect(byId('D').oppMatchWinPct, closeTo(0.50, 1e-9));
    });
  });

  group('Byes', () {
    test('bye grants 3 match points but is excluded from GW%', () {
      final players = const [Player(id: 'X', name: 'X')];
      final rounds = [
        Round(number: 1, matches: [Match.bye('X')]),
      ];
      final s = StandingsCalculator.compute(players, rounds).single;
      expect(s.matchPoints, 3);
      expect(s.gameWinPct, 0.0); // no games played → not floored to 0.33
    });
  });

  group('Swiss pairing', () {
    test('odd field produces exactly one bye and pairs the rest', () {
      final players = [
        for (var i = 0; i < 5; i++) Player(id: '$i', name: 'P$i'),
      ];
      final matches = SwissPairing.pairNextRound(
        players: players,
        previousRounds: const [],
        random: Random(42),
      );
      final byes = matches.where((m) => m.isBye).toList();
      expect(byes.length, 1);

      final paired = <String>{};
      for (final m in matches) {
        paired.add(m.player1Id);
        if (m.player2Id != null) paired.add(m.player2Id!);
      }
      expect(paired.length, 5); // everyone appears exactly once
    });

    test('dropped players are not paired', () {
      final players = [
        const Player(id: '0', name: 'P0'),
        const Player(id: '1', name: 'P1'),
        const Player(id: '2', name: 'P2', dropped: true),
        const Player(id: '3', name: 'P3'),
      ];
      final matches = SwissPairing.pairNextRound(
        players: players,
        previousRounds: const [],
        random: Random(1),
      );
      for (final m in matches) {
        expect(m.involves('2'), isFalse);
      }
    });

    test('avoids rematches when a valid pairing exists', () {
      final players = [
        for (var i = 0; i < 4; i++) Player(id: '$i', name: 'P$i'),
      ];
      // Round 1: 0v1, 2v3 (all reported).
      final r1 = Round(number: 1, matches: [
        Match.pairing('0', '1')
            .withResult(const MatchResult(player1GameWins: 2, player2GameWins: 0)),
        Match.pairing('2', '3')
            .withResult(const MatchResult(player1GameWins: 2, player2GameWins: 0)),
      ]);

      final next = SwissPairing.pairNextRound(
        players: players,
        previousRounds: [r1],
        random: Random(7),
      );

      bool sameAs(Match m, String a, String b) =>
          (m.player1Id == a && m.player2Id == b) ||
          (m.player1Id == b && m.player2Id == a);

      for (final m in next) {
        expect(sameAs(m, '0', '1'), isFalse, reason: 'rematch 0v1');
        expect(sameAs(m, '2', '3'), isFalse, reason: 'rematch 2v3');
      }
    });
  });
}
