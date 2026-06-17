# MTG Tournament

Оффлайн-менеджер MTG-турниров: регистрация участников → швейцарские раунды →
стендинги и тай-брейки по правилам WotC → топ-кат (single elimination).

Монорепозиторий из двух частей:

- **Корень** — чистый Dart-пакет `mtg_tournament_engine`: ядро движка
  (швейцарские париринги, стендинги, тай-брейки, топ-кат). **Без Flutter и без БД** —
  модуль переиспользуем и полностью покрыт юнит-тестами.
- **`app/`** — Flutter-приложение под телефон. Подключает движок как path-зависимость
  и содержит только UI и хранилище (один JSON-файл в каталоге документов).

## Движок (корень)

Иммутабельные модели, чистые функции, история раундов — единственный источник истины.

- `lib/src/models.dart` — `Player`, `Match`, `MatchResult`, `Round`. Репорт результата
  создаёт новый объект, история не затирается.
- `lib/src/standings.dart` — `StandingsCalculator`: матч-поинты и тай-брейки
  (OMW% → GW% → OGW%) с флором 33%. Стендинги всегда пересчитываются из истории.
- `lib/src/swiss_pairing.dart` — `SwissPairing`: париринги следующего раунда,
  избегание рематчей (бэктрекинг), назначение бая.
- `lib/src/tournament.dart` — агрегат `Tournament` (+ `toJson/fromJson`) — единственный
  сериализуемый объект.
- `lib/src/top_cut.dart` — `TopCut`: сидинг и продвижение по сетке плей-офф.

### Тесты

```bash
dart pub get
dart test
dart analyze
```

### Пример

```dart
import 'package:mtg_tournament_engine/tournament_engine.dart';

final players = [
  Player(id: 'p1', name: 'Alice'),
  Player(id: 'p2', name: 'Bob'),
  Player(id: 'p3', name: 'Carol'),
];

// Раунд 1
var matches = SwissPairing.pairNextRound(players: players, previousRounds: []);

// Репорт результата (иммутабельно; счёт — в партиях, не в матчах)
matches[0] = matches[0].withResult(
  const MatchResult(player1GameWins: 2, player2GameWins: 1),
);

final rounds = [Round(number: 1, matches: matches)];

// Стендинги
for (final s in StandingsCalculator.compute(players, rounds)) print(s);

// Следующий раунд — уже по стендингам, без рематчей
final next = SwissPairing.pairNextRound(players: players, previousRounds: rounds);
```

## Приложение (`app/`)

Требуется установленный Flutter SDK. Платформенные папки (`android/`, `ios/`,
`macos/`, …) **не закоммичены** — генерируются один раз локально:

```bash
cd app
flutter create .          # создаст android/, ios/ и прочие платформенные файлы
flutter pub get
flutter run               # на подключённом устройстве / эмуляторе
```

`flutter create .` не перезаписывает существующие `lib/` и `pubspec.yaml`.

### Структура

- `lib/data/tournament_repository.dart` — чтение/запись турнира в JSON-файл.
- `lib/state/tournament_controller.dart` — `ChangeNotifier`: все операции над турниром
  с автосохранением; стендинги считаются на лету через движок.
- `lib/screens/` — `setup`, `swiss` (раунд + стендинги), `top_cut`, `result_dialog`.
- `lib/main.dart` — загрузка состояния и роутинг по `TournamentStatus`.

### Проверка

```bash
flutter analyze
flutter test
```

### Сборка APK (Android)

```bash
cd app
flutter build apk --release                 # один «толстый» APK (все ABI)
flutter build apk --release --split-per-abi # отдельные APK по архитектурам
```

Готовые сборки лежат в **`app/dist/`**: для большинства современных телефонов —
`app-arm64-v8a-release.apk`. Подпись — debug-ключом (годится для установки на свои
устройства; для Google Play нужен release-keystore).

## Сознательное упрощение

Париринги делаются «по порядку стендингов» с бэктрекингом против рематчей — это даёт
корректную швейцарку без повторов. Точный алгоритм WotC (фолд внутри групп с равными
очками) можно навесить позже, **не меняя модель данных**.
