# GalaryGame — геймификация цифрового порядка

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
xcodegen generate          # создаёт GalaryGame.xcodeproj
open GalaryGame.xcodeproj
```

В Xcode выбери свою Development Team в настройках таргета (для запуска на устройстве —
доступ к настоящей галерее нужен именно на реальном iPhone) и жми Run.

Тесты: `Cmd+U` в Xcode, либо
`xcodebuild test -scheme GalaryGame -destination 'platform=iOS Simulator,name=iPhone 15'`.

> ⚠️ Сборка/запуск требуют macOS + Xcode. На Linux (CI без Xcode) можно только
> читать/править код — скомпилировать нативный iOS-таргет там нельзя.

## Архитектура

```
GalaryGame/
  App/            — точка входа, SwiftData-контейнер, GameStore (координатор), RootView
  Models/         — @Model-сущности (UserProfile, CleanupEvent, Achievement, Quest) + enum'ы
  Engine/         — ЧИСТАЯ логика без зависимостей: ScoringEngine, GamificationEngine, QuestFactory
  Services/       — PhotoLibraryService (PhotoKit), ClutterAnalyzer (Vision/Core Image)
  Features/       — экраны: Onboarding, Dashboard, Cleanup (свайп-триаж), Achievements, Garden
  DesignSystem/   — Theme, DOSRing, AssetImage, Card
GalaryGameTests/  — юнит-тесты чистой логики (движки, квесты)
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
| Галерея | ✅ полный доступ | PhotoKit: счёт, детект, удаление (системный диалог), альбомы |
| Красивый рабочий стол | ❌ нельзя читать домашний экран | план: загрузка скриншота + Vision (Фаза 6) |
| Файлы/загрузки | ⚠️ песочница | план: `UIDocumentPicker` по выбранным папкам (Фаза 6) |
| «Недавно удалённые» | ⚠️ контент недоступен публично | метрика `recentlyDeleted` = 0 |

## Дальше (Фаза 6+)

Режим «рабочий стол» (скриншот + Vision), режим «файлы» (document picker),
облачный рейтинг очков через Supabase (opt-in, без фото), локализация RU/EN, freemium.
