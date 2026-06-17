# MTG TOURNAMENT

Ядро оффлайн-приложения для проведения MTG-турниров: швейцарские париринги,
стендинги и тай-брейки по правилам WotC. Чистый Dart — **без Flutter и без БД**,
поэтому модуль можно подключить в любой Flutter-проект и полностью покрыть
юнит-тестами.

## Что внутри

- `lib/src/models.dart` — `Player`, `Match`, `MatchResult`, `Round`. Всё
  иммутабельное: репорт результата создаёт новый объект, история не затирается.
- `lib/src/standings.dart` — `StandingsCalculator`: матч-поинты и тай-брейки
  (OMW% → GW% → OGW%) с флором 33%. Стендинги всегда пересчитываются из
  истории, ничего не кэшируется.
- `lib/src/swiss_pairing.dart` — `SwissPairing`: париринги следующего раунда,
  избегание рематчей (бэктрекинг), назначение бая.

## Запуск тестов

```bash
cd mtg_tournament_engine
dart pub get
dart test
```

## Пример

```dart
import 'package:mtg_tournament_engine/tournament_engine.dart';

final players = [
  Player(id: 'p1', name: 'Alice'),
  Player(id: 'p2', name: 'Bob'),
  Player(id: 'p3', name: 'Carol'),
];

// Раунд 1
var matches = SwissPairing.pairNextRound(
  players: players,
  previousRounds: [],
);

// Репорт результата (иммутабельно)
matches[0] = matches[0].withResult(
  const MatchResult(player1GameWins: 2, player2GameWins: 1),
);

final rounds = [Round(number: 1, matches: matches)];

// Стендинги
final table = StandingsCalculator.compute(players, rounds);
for (final s in table) print(s);

// Следующий раунд — уже по стендингам, без рематчей
final next = SwissPairing.pairNextRound(
  players: players,
  previousRounds: rounds,
);
```

## Сознательное упрощение

Париринги делаются «по порядку стендингов» с бэктрекингом против рематчей —
это даёт корректную швейцарку без повторов. Точный алгоритм WotC (фолд внутри
групп с равными очками) можно навесить позже, **не меняя модель данных**.

## Дальше

1. Слой хранения (drift / SQLite): таблицы `tournaments`, `players`, `rounds`,
   `matches` поверх этих же моделей.
2. UI на Flutter: список игроков → текущий раунд → ввод результатов →
   стендинги.
3. Экспорт (JSON-бэкап, CSV/PDF) и топ-кат (single elimination) после швейцарки.
