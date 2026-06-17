import 'dart:convert';
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

    test('honors fixed pairings and byes, auto-pairs the rest', () {
      final players = [
        for (var i = 0; i < 5; i++) Player(id: '$i', name: 'P$i'),
      ];
      final fixed = [
        Match.pairing('0', '4'),
        Match.bye('1'),
      ];
      final matches = SwissPairing.pairNextRound(
        players: players,
        previousRounds: const [],
        fixedMatches: fixed,
        random: Random(3),
      );

      bool sameAs(Match m, String a, String b) =>
          (m.player1Id == a && m.player2Id == b) ||
          (m.player1Id == b && m.player2Id == a);

      // The fixed pairing and bye are present exactly as given.
      expect(matches.any((m) => !m.isBye && sameAs(m, '0', '4')), isTrue);
      expect(matches.any((m) => m.isBye && m.player1Id == '1'), isTrue);

      // Fixed players never appear in the auto-paired remainder.
      final auto = matches
          .where((m) => !(m.isBye && m.player1Id == '1') && !sameAs(m, '0', '4'))
          .toList();
      for (final m in auto) {
        expect(m.involves('0'), isFalse);
        expect(m.involves('4'), isFalse);
        expect(m.involves('1'), isFalse);
      }

      // The remaining players (2, 3) are paired together; everyone appears once.
      final seen = <String>{};
      for (final m in matches) {
        expect(seen.add(m.player1Id), isTrue);
        if (m.player2Id != null) expect(seen.add(m.player2Id!), isTrue);
      }
      expect(seen, {'0', '1', '2', '3', '4'});
    });
  });

  group('Serialization', () {
    test('Tournament round-trips through JSON', () {
      final tournament = Tournament(
        id: 't1',
        config: const TournamentConfig(
          name: 'Friday Night Magic',
          swissRounds: 3,
          bestOf: 3,
          topCutSize: 4,
        ),
        players: const [
          Player(id: 'A', name: 'Alice'),
          Player(id: 'B', name: 'Bob', dropped: true),
        ],
        swissRounds: [
          Round(number: 1, matches: [
            Match.pairing('A', 'B').withResult(
                const MatchResult(player1GameWins: 2, player2GameWins: 1)),
            Match.bye('A'),
          ]),
        ],
        status: TournamentStatus.swiss,
      );

      final restored = Tournament.fromJson(
          (jsonDecode(jsonEncode(tournament.toJson())) as Map)
              .cast<String, dynamic>());

      expect(restored.id, 't1');
      expect(restored.config.name, 'Friday Night Magic');
      expect(restored.config.topCutSize, 4);
      expect(restored.status, TournamentStatus.swiss);
      expect(restored.players.length, 2);
      expect(restored.players[1].dropped, isTrue);

      final r1 = restored.swissRounds.single;
      expect(r1.matches.first.result.toString(), '2-1');
      expect(r1.matches.last.isBye, isTrue);
      expect(r1.matches.last.result, isNull);
    });

    test('manualFirstRound round-trips and defaults to empty', () {
      final tournament = Tournament(
        id: 't2',
        config: const TournamentConfig(name: 'Prerelease', swissRounds: 3),
        players: const [
          Player(id: 'A', name: 'Alice'),
          Player(id: 'B', name: 'Bob'),
          Player(id: 'C', name: 'Cara'),
        ],
        manualFirstRound: [
          Match.pairing('A', 'B'),
          Match.bye('C'),
        ],
      );

      final restored = Tournament.fromJson(
          (jsonDecode(jsonEncode(tournament.toJson())) as Map)
              .cast<String, dynamic>());
      expect(restored.manualFirstRound.length, 2);
      expect(restored.manualFirstRound.first.player2Id, 'B');
      expect(restored.manualFirstRound.last.isBye, isTrue);

      // Old saves without the key load as an empty list.
      final legacy = Tournament.fromJson({
        'id': 't3',
        'config': const TournamentConfig(name: 'X', swissRounds: 3).toJson(),
        'players': const [],
        'status': 'registering',
      });
      expect(legacy.manualFirstRound, isEmpty);
    });

    test('recommendedSwissRounds uses ceil(log2(n))', () {
      expect(recommendedSwissRounds(8), 3);
      expect(recommendedSwissRounds(9), 4);
      expect(recommendedSwissRounds(16), 4);
      expect(recommendedSwissRounds(1), 0);
    });
  });

  group('Top cut', () {
    List<Standing> standingsFor(int n) {
      // Build a field where seed order equals player index (0 = top seed).
      final players = [for (var i = 0; i < n; i++) Player(id: 'p$i', name: 'P$i')];
      // One round where lower index always beats higher index, giving a clean
      // descending standings order p0 > p1 > ... by match points.
      final matches = <Match>[];
      for (var i = 0; i + 1 < n; i += 2) {
        matches.add(Match.pairing('p$i', 'p${i + 1}').withResult(
            const MatchResult(player1GameWins: 2, player2GameWins: 0)));
      }
      final standings =
          StandingsCalculator.compute(players, [Round(number: 1, matches: matches)]);
      // Force deterministic rank == index for the test bracket.
      return [
        for (var i = 0; i < n; i++)
          standings.firstWhere((s) => s.player.id == 'p$i').copyWith(rank: i + 1),
      ];
    }

    test('top 8 seeds 1v8, 4v5, 2v7, 3v6', () {
      final round = TopCut.seed(standingsFor(8), 8);
      expect(round.matches.length, 4);
      expect(round.matches[0].player1Id, 'p0'); // seed 1
      expect(round.matches[0].player2Id, 'p7'); // seed 8
      expect(round.matches[1].player1Id, 'p3'); // seed 4
      expect(round.matches[1].player2Id, 'p4'); // seed 5
      expect(round.matches[2].player1Id, 'p1'); // seed 2
      expect(round.matches[2].player2Id, 'p6'); // seed 7
      expect(round.matches[3].player1Id, 'p2'); // seed 3
      expect(round.matches[3].player2Id, 'p5'); // seed 6
    });

    test('advances winners to a champion', () {
      var round = TopCut.seed(standingsFor(8), 8);
      // Top seed of each match (player1) always wins.
      Round playOut(Round r) => Round(
            number: r.number,
            matches: [
              for (final m in r.matches)
                m.withResult(
                    const MatchResult(player1GameWins: 2, player2GameWins: 0)),
            ],
          );

      round = playOut(round); // quarterfinals
      var semis = TopCut.nextRound(round);
      expect(semis.matches.length, 2);
      semis = playOut(semis);
      var fin = TopCut.nextRound(semis);
      expect(fin.matches.length, 1);
      fin = playOut(fin);
      expect(TopCut.championOf(fin), 'p0'); // overall top seed wins
    });
  });
}
