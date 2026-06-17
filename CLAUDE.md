# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Что это

Монорепо из двух частей:

- **Корень** — чистый Dart-пакет `mtg_tournament_engine`: ядро движка (швейцарские
  париринги, стендинги, тай-брейки WotC, агрегат турнира, топ-кат). **Без Flutter и без БД** —
  сознательное ограничение, чтобы движок был переиспользуемым и полностью покрытым тестами.
  **Не добавляй зависимости от Flutter, I/O, сети или хранилища в корневой `lib/`.**
- **`app/`** — Flutter-приложение (оффлайн-менеджер турниров на телефоне), подключает движок
  как path-зависимость. Здесь живут UI, хранилище (JSON-файл) и контроллер состояния.

## Команды

Движок (из корня):
```bash
dart pub get            # установить зависимости
dart test               # все тесты
dart test test/engine_test.dart -N "match points are correct"   # один тест по имени
dart analyze            # статический анализ
```

Приложение (из `app/`, требует Flutter SDK):
```bash
flutter create .        # один раз: сгенерировать android/ ios/ (не перезаписывает lib/)
flutter pub get
flutter run             # запуск на устройстве/эмуляторе
flutter analyze && flutter test
```

## Архитектура

Публичный API экспортируется через единственный файл `lib/tournament_engine.dart`.
Три слоя в `lib/src/`:

- **`models.dart`** — `Player`, `MatchResult`, `Match`, `Round`. Всё иммутабельно.
  Изменение состояния (репорт результата, дроп игрока) создаёт новый объект через
  `withResult` / `copyWith`, а не мутирует существующий. История раундов — единственный
  источник истины.

- **`standings.dart`** — `StandingsCalculator.compute(players, rounds)` → `List<Standing>`.
  Чистая функция: стендинги **всегда пересчитываются из сырой истории раундов**, ничего
  не кэшируется. Внутренний `_Agg` — аккумулятор на игрока.

- **`swiss_pairing.dart`** — `SwissPairing.pairNextRound(...)` → `List<Match>`. Для не-первого
  раунда вызывает `StandingsCalculator.compute`, сортирует игроков по рангу и парит соседей
  с бэктрекингом против рематчей.

- **`tournament.dart`** — агрегат `Tournament` (id, config, players, swissRounds, topCutRounds,
  status) + `TournamentConfig` + `TournamentStatus`. Иммутабельный, c `toJson/fromJson` —
  это единственный объект, который сериализует приложение. Хелпер `recommendedSwissRounds`.

- **`top_cut.dart`** — `TopCut.seed(standings, size)` строит первый раунд single-elimination
  (стандартный сидинг 4/8), `TopCut.nextRound(prev)` продвигает победителей, `championOf`.

Зависимости строго однонаправленные: `top_cut`/`swiss_pairing` → `standings` → `models`;
`tournament` → `models`.

### Flutter-приложение (`app/`)

- `lib/state/tournament_controller.dart` — `ChangeNotifier`, единая точка мутаций турнира:
  каждая операция создаёт новый `Tournament`, уведомляет слушателей и **автосохраняет** через
  репозиторий. Стендинги считаются на лету (инвариант движка — ничего не кэшировать).
- `lib/data/tournament_repository.dart` — JSON-файл в каталоге документов (`path_provider`).
- `lib/screens/` — `setup` → `swiss` (раунд + стендинги) → `top_cut`; роутинг по
  `TournamentStatus` в `main.dart` через `ListenableBuilder`.
- Платформенные папки `android/`/`ios/` не в git — генерируются `flutter create .`.

Все JSON-методы моделей (`toJson/fromJson`) лежат в движке; приложение их только вызывает.

### Ключевые инварианты (легко сломать при правках)

- **Бай** = 3 матч-поинта и засчитывается как победа, но **исключён из всех процентов
  (MWP/GW%/OMW%/OGW%) и никогда не считается оппонентом**. См. обработку `m.isBye` в
  `standings.dart` и поля `pctMatchPoints` / `pctMatches` / `opponents` в `_Agg`.
- **Флор процентов** = `StandingsCalculator.minPercentage` (0.33). Применяется к
  индивидуальным MWP и GW% каждого игрока перед усреднением по оппонентам.
- **Счёт в `MatchResult` — это игры (games), не матчи.** Матч-поинты выводятся из
  сравнения `player1GameWins` vs `player2GameWins`.
- **Порядок тай-брейков** (WotC MTR Appendix C): match points → OMW% → GW% → OGW%,
  затем имя игрока как стабильный финальный фолбэк. См. `standings.sort(...)`.
- Дропнутый игрок (`Player.dropped`) сохраняет прошлые результаты и остаётся в стендингах,
  но не парится в будущих раундах (`SwissPairing` фильтрует `!p.dropped`).
- Пары хранятся order-independent через `_key(a, b)` (сортировка id) — учитывай это при
  работе с множеством сыгранных пар.

### Сознательные упрощения

Париринги делаются «по порядку стендингов» с бэктрекингом, а не точным WotC-алгоритмом
(фолд внутри групп с равными очками). Если рематч-фри пары не существует, есть фолбэк на
последовательную разбивку. Любые улучшения алгоритма должны идти **без изменения модели
данных** в `models.dart`.

## Стиль

API-документация и комментарии в коде — на английском (см. существующие dartdoc-комментарии).
Общение с пользователем — на русском.
