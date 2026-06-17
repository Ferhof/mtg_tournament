import 'package:flutter/material.dart';
import 'package:mtg_tournament_engine/tournament_engine.dart';

/// A scrollable list of standings rows (rank, name, tiebreakers, match points).
/// Shared between the live Swiss standings tab and the final results screen.
class StandingsList extends StatelessWidget {
  const StandingsList({
    super.key,
    required this.standings,
    this.padding = const EdgeInsets.all(12),
    this.shrinkWrap = false,
    this.physics,
  });

  final List<Standing> standings;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: standings.length,
      itemBuilder: (context, i) {
        final s = standings[i];
        return ListTile(
          leading: CircleAvatar(child: Text('${s.rank}')),
          title: Text(
            s.player.name + (s.player.dropped ? ' (dropped)' : ''),
          ),
          subtitle: Text(
            'OMW ${(s.oppMatchWinPct * 100).toStringAsFixed(1)}%  '
            'GW ${(s.gameWinPct * 100).toStringAsFixed(1)}%  '
            'OGW ${(s.oppGameWinPct * 100).toStringAsFixed(1)}%',
          ),
          trailing: Text(
            '${s.matchPoints} pts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        );
      },
    );
  }
}
