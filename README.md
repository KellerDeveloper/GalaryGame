# TrashPanda — геймификация цифрового порядка

Нативное iOS-приложение (Swift + SwiftUI), которое превращает наведение порядка в
галерее телефона в игру: очки (XP), уровни, стрики, ежедневные задания, ачивки и
растущий «сад порядка». Всё распознавание фото происходит **на устройстве** —
снимки никуда не отправляются.

> Это MVP-каркас (Фазы 0–5 по плану): ядро — работа с галереей.

## Как открыть и собрать

Проект хранится в виде исходников + спецификации [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`.xcodeproj` не коммитится — генерируется). На macOS с Xcode 15+:

```bash
brew install xcodegen      # один раз
xcodegen generate          # создаёт TrashPanda.xcodeproj
open TrashPanda.xcodeproj
```

В Xcode выбери свою Development Team в настройках таргета (для запуска на устройстве —
доступ к настоящей галерее нужен именно на реальном iPhone) и жми Run.

Тесты: `Cmd+U` в Xcode, либо
`xcodebuild test -scheme TrashPanda -destination 'platform=iOS Simulator,name=iPhone 15'`.

> ⚠️ Сборка/запуск требуют macOS + Xcode. На Linux (CI без Xcode) можно только
> читать/править код — скомпилировать нативный iOS-таргет там нельзя.

## Архитектура

```
TrashPanda/
  App/            — точка входа, SwiftData-контейнер, GameStore (координатор), RootView
  Models/         — @Model-сущности (UserProfile, CleanupEvent, Achievement, Quest) + enum'ы
  Engine/         — ЧИСТАЯ логика без зависимостей: ScoringEngine, GamificationEngine, QuestFactory
  Services/       — PhotoLibraryService (PhotoKit), ClutterAnalyzer (Vision/Core Image),
                    FileCleanupService (сканер файлов), LeaderboardService (Supabase REST)
  Features/       — экраны: Onboarding, Dashboard, Cleanup (свайп-триаж + раскладка
                    по альбомам), Files, Achievements, Garden, Leaderboard
  DesignSystem/   — Theme, DOSRing, AssetImage, Card
supabase/migrations/ — SQL схема лидерборда (RLS)
TrashPandaTests/  — юнит-тесты чистой логики (движки, квесты, файловый сканер)
```

**Поток данных:** UI → `GameStore.recordCleanup(...)` → `ScoringEngine`/`GamificationEngine`
считают XP/стрик/ачивки → SwiftData сохраняет → UI обновляется. Тяжёлый анализ
(дубликаты/размытость) идёт через `ClutterAnalyzer` на фоне.

## Игровая механика

- **Digital Order Score (0–100)** — «рейтинг чистоты» галереи из долей дубликатов,
  размытых, скриншотов и не-разложенных фото (`ScoringEngine.digitalOrderScore`).
- **XP** за действия: дубликат/размытое +5, скриншот +3, фото в альбом +2,
  очистка корзины +20, +1 за каждые 100 МБ (`CleanupType.baseXP`).
- **Ранги:** Хаос → Новичок → Организатор → Минималист → Дзен-мастер (`Rank`).
- **Стрики** с «заморозкой» на пропущенный день (`GamificationEngine.updateStreak`).
- **Ежедневные задания** (детерминированные на день, `QuestFactory`).
- **Ачивки** (`AchievementID`) и **сад порядка**, растущий вместе с DOS (`GardenView`).
- **Свайп-триаж** «Tinder для фото»: влево — удалить, вправо — оставить (`SwipeTriageView`).

## Ограничения iOS (заложены честно)

| Что | Статус | Как |
|---|---|---|
| Галерея | ✅ полный доступ | PhotoKit: счёт, детект, удаление (системный диалог), **раскладка по альбомам** |
| Файлы/загрузки | ✅ выбранная папка | `.fileImporter` по папкам «Файлов» (iCloud Drive / «На iPhone»); общая «Загрузки» и кэш мессенджеров недоступны |
| Красивый рабочий стол | ❌ нельзя читать домашний экран | план: загрузка скриншота + Vision |
| «Недавно удалённые» | ⚠️ контент недоступен публично | метрика `recentlyDeleted` = 0 |

## Облачный рейтинг (Supabase, opt-in)

Синхронизируются **только** имя + XP + рейтинг порядка. Фото и метаданные галереи
никогда не отправляются. Off по умолчанию.

1. Применить схему: `supabase/migrations/0001_leaderboard.sql` (Supabase MCP
   `apply_migration`, `supabase db push` или SQL-редактор дашборда).
2. Заполнить `TrashPanda/App/SupabaseConfig.swift` — `url` и `anonKey` проекта
   (anon-ключ публичный по дизайну, доступ ограничен RLS).

Пока ключи пустые, `LeaderboardService` безопасно no-op'ит, а экран «Рейтинг»
показывает «не настроен» — остальное приложение работает как обычно.

## Дальше

Режим «рабочий стол» (скриншот + Vision), локализация RU/EN, freemium.
