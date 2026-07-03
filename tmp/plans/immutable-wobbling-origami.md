# План итерации 3 — TrashPanda (бэклог «11 - Идеи развития»)

## Context

Приложение **TrashPanda** (SwiftUI + SwiftData, iOS 17) — геймифицированная уборка галереи/файлов.
MVP + итерация 2 уже есть. Задача: реализовать 🔥-ядро бэклога из
`Obsidian/.../GalaryGame/11 - Идеи развития.md`.

Пользователь выбрал **6 фич за итерацию** (амбициозно):
1. Анимация награды (+XP / конфетти / поп-бейджей) — 🔥
2. Умная приоритизация на Dashboard («самое жирное первым») — 🔥
3. Расширить ачивки + престиж-ранги — ⚙️
4. Кэш результатов Vision-анализа — 🔥
5. Пуш-уведомления о стрике — 🔥 retention
6. Виджет на домашний экран (WidgetKit) — 🔥 retention

Продуктовые решения (утверждены):
- **Престиж:** 3 именных ранга поверх Дзен-мастера — Куратор (5000), Архивариус (10000), Легенда порядка (25000).
- **Новые ачивки:** «100 дней стрика», «10 ГБ освобождено», «100 фото разложено».
- **Анимация:** полный фарш (тосты +XP, конфетти на rank-up, поп-ап бейджей).

### Опорные факты из кода (сверено по исходникам)
- `GameStore.recordCleanup(type:count:bytesFreed:) -> CleanupOutcome` — **единственная точка наград**;
  все вызывающие (`SwipeTriageView.commit`, `AlbumSortView.assign/createAndAssign`, `FilesView.deleteSelected`)
  сейчас `@discardableResult` **выбрасывают** результат. Значит анимацию цепляем централизованно.
- `Rank` — `enum Int` (5 кейсов), пороги/титулы/символы в switch'ах; `rank(forXP:)` = `allCases.last{…}`,
  `next` = `Rank(rawValue: rawValue+1)`. Добавление кейсов безопасно.
- `AchievementID` — `enum String`; условия в `GamificationEngine.unlockedAchievements(for: PlayerStats)`.
  `PlayerStats` агрегируется в `GameStore.aggregateStats()` из `CleanupEvent` (сейчас считает только
  `duplicatesDeleted`, `screenshotsTriaged`; `sortToAlbum` НЕ агрегируется → надо добавить `photosSorted`).
- `DashboardViewModel.findDuplicates/findBlurry` гоняют Vision по каждому фото **при каждом запуске** —
  цель кэша. `PhotoLibraryService.estimatedByteSize(of:)` уже есть → база для «самого жирного».
- Схема SwiftData в `TrashPandaApp`: `[UserProfile, CleanupEvent, Achievement, Quest]`.
- Сборка: MCP xcode-tools в сессии НЕ подключён → собираю через `xcodegen` (стоит) + `xcodebuild`.
- Тесты — XCTest (`@testable import TrashPanda`).
- `Info.plist`: `GENERATE_INFOPLIST_FILE: NO` (важно для виджет-таргета — нужен свой Info.plist).

---

## Порядок реализации (безопасные инкременты)

Кодю пачкой, но собираю/тестирую между шагами; фичи 1–5 — в основном таргете (один билд),
виджет — последним и изолированным, чтобы возможный провал подписи не блокировал остальное.

### Шаг 1. Ранги + ачивки (движки/модели) + тесты
- `Models/Rank.swift`: добавить кейсы `curator, archivist, legend` в enum + в `xpThreshold`
  (5000/10000/25000), `title` (Куратор/Архивариус/Легенда порядка), `symbolName`
  (напр. `crown`, `books.vertical.fill`, `laurel.leading`).
- `Models/Achievement.swift`: добавить `AchievementID` кейсы `streakHundred, freedTenGigs, sortedHundred`
  + `title`/`detail`/`symbolName`.
- `Engine/GamificationEngine.swift` (`unlockedAchievements`): условия
  `streakCount >= 100`, `storageFreedBytes >= 10 ГБ`, `photosSorted >= 100`.
- `Engine/GamificationEngine.swift` (`PlayerStats`): добавить `var photosSorted: Int = 0`.
- `App/GameStore.swift` (`aggregateStats`): в switch добавить `case .sortToAlbum: stats.photosSorted += e.count`.
- Тесты: `TrashPandaTests/GamificationEngineTests.swift` — обновить `testRankProgress`
  (топ теперь `.legend`; проверять `Rank.legend.progress(...) == 1.0`), добавить пороги новых рангов,
  расширить `testAchievementUnlocks` новыми stat'ами/ассертами.

### Шаг 2. Анимация награды (централизованно + локально)
- `App/GameStore.swift`: добавить наблюдаемое `private(set) var reward: RewardEvent?`
  (`struct RewardEvent { xp; didRankUp; newRank; unlocked: [AchievementID] }`) + приватный аккумулятор.
  `recordCleanup` после расчёта **сам** кладёт свой `CleanupOutcome` в аккумулятор и планирует
  `Task { @MainActor … }`, который сливает подряд идущие вызовы (сумма XP, OR didRankUp, union unlocked)
  в один `reward` — так двойной вызов в `SwipeTriageView.commit` (тип + `.storageFreed`) даёт один эффект.
  Добавить `func clearReward()`.
- `DesignSystem/RewardOverlay.swift` (новый): слушает `store.reward` — плавающий «+N XP»,
  на `didRankUp` — самописное `ConfettiView` (частицы SwiftUI, без сторонних пакетов) + баннер нового ранга,
  на `unlocked` — поп-ап бейджей по очереди. По завершении зовёт `store.clearReward()`.
- `App/RootView.swift` (`MainTabView`): `.overlay { RewardOverlay(store: store) }` поверх табов
  (показывается после закрытия модалок — общий итог + rank-up).
- Мгновенный локальный «+XP» **внутри** модалок (для юмора при открытом fullScreenCover):
  `SwipeTriageView.commit` и `AlbumSortView.assign/createAndAssign` — захватить возвращаемый
  `CleanupOutcome` и показать короткий локальный флеш «+xpGained».

### Шаг 3. Умная приоритизация на Dashboard
- `Features/Dashboard/DashboardViewModel.swift`:
  - `findDuplicates()` — считать реклэйм-байты на группу (сумма `estimatedByteSize` «лишних» из группы),
    сортировать группы по байтам ↓, флэттенить `dropFirst` в этом порядке (тяжёлые первыми);
    сохранять `duplicateReclaimBytes`.
  - Добавить оценку реклэйма по категориям (скриншоты: сумма размеров; после тяжёлого скана — дубликаты/размытые),
    отдавать отсортированный список «biggest wins».
- `Features/Dashboard/DashboardView.swift`: новая карточка **«Что разобрать первым»** — категории,
  ранжированные по оценке освобождаемого места (тяжёлое сверху), каждая тапабельна и запускает свой флоу.

### Шаг 4. Кэш Vision-анализа
- `Models/AssetAnalysis.swift` (новый `@Model`): `@Attribute(.unique) var localIdentifier`,
  `sharpness: Double`, `featurePrintData: Data?`, `assetModified: Date?`, `analyzedAt: Date`.
- `Services/AnalysisCache.swift` (новый): держит `ModelContext`; `sharpness(for:compute:)` и
  `featurePrint(for:compute:)` — по `localIdentifier` + `asset.modificationDate` возвращают кэш
  либо считают через `ClutterAnalyzer` и upsert'ят. Feature print — `NSKeyedArchiver`/`NSKeyedUnarchiver`
  (`VNFeaturePrintObservation` конформит `NSSecureCoding`).
- `App/TrashPandaApp.swift`: добавить `AssetAnalysis.self` в `Schema`.
- `DashboardViewModel.findDuplicates/findBlurry`: считать через `AnalysisCache(context: store.modelContext)`
  вместо прямого пересчёта.
- Инвалидация: пересчёт если `assetModified` изменился или нет сохранённого print.
- (Опц.) лёгкий тест upsert/lookup на in-memory `ModelContainer`.

### Шаг 5. Пуш-уведомления о стрике
- `Services/NotificationService.swift` (новый): обёртка `UNUserNotificationCenter` —
  `requestAuthorizationIfNeeded()`, `scheduleStreakReminder(streak:)` (локальный
  `UNCalendarNotificationTrigger` на завтра 20:00, стабильный id → replace),
  `cancelStreakReminder()`. Тело: «Твой стрик N дней под угрозой — заскочи навести порядок 🔥».
- `App/GameStore.swift`: держит `NotificationService?`; в `recordCleanup` после апдейта стрика
  зовёт `reschedule(streak:)`; при первом успешном клинапе — разовый `requestAuthorizationIfNeeded()`
  (флаг в `UserDefaults`). Локальным уведомлениям ключ в Info.plist не нужен.
- Инициализация сервиса — в `RootView`/`GameStore` init.

### Шаг 6. Виджет (WidgetKit) — изолированно, последним
- `Shared/GameSnapshot.swift` (в обоих таргетах): `struct GameSnapshot: Codable { dosScore; streakCount; todayCleaned }`
  + `enum AppGroup { static let id = "group.com.kellerdeveloper.trashpanda"; save/load через UserDefaults(suiteName:) }`.
- `App/GameStore.swift`: после `save()` в `recordCleanup`/`updateScore` писать снапшот +
  `WidgetCenter.shared.reloadAllTimelines()`.
- `TrashPandaWidget/` (новый app-extension таргет): `TrashPandaWidgetBundle`, `Provider: TimelineProvider`,
  компактный вид (DOS-кольцо + стрик 🔥 + «сегодня N»). UI самодостаточный (мини-палитра в Shared).
- Entitlements: `TrashPanda/TrashPanda.entitlements` и `TrashPandaWidget/TrashPandaWidget.entitlements`
  с `com.apple.security.application-groups = [group.com.kellerdeveloper.trashpanda]`.
- `project.yml`: новый таргет `TrashPandaWidgetExtension` (type app-extension, свой Info.plist с NSExtension
  WidgetKit), `CODE_SIGN_ENTITLEMENTS` обоим, app зависит и embed'ит виджет.
- Затем `xcodegen generate` + сборка.

> **Риск (честно):** виджет тянет App Groups + entitlements. На симуляторе сборка обычно проходит
> без `DEVELOPMENT_TEAM` (ad-hoc подпись), но не гарантированно. Если headless-сборка виджета упадёт по
> подписи — фичи 1–5 уже собраны; код виджета оставляю, ты добьёшь его сборку в Xcode со своим Team.
> Об этом сразу доложу, а не буду прятать.

---

## Файлы

**Изменяю:** `Models/Rank.swift`, `Models/Achievement.swift`, `Engine/GamificationEngine.swift`,
`App/GameStore.swift`, `Features/Dashboard/DashboardViewModel.swift`, `Features/Dashboard/DashboardView.swift`,
`Features/Cleanup/SwipeTriageView.swift`, `Features/Cleanup/AlbumSortView.swift`, `App/TrashPandaApp.swift`,
`App/RootView.swift`, `project.yml`, `TrashPandaTests/GamificationEngineTests.swift`.

**Создаю:** `DesignSystem/RewardOverlay.swift` (+ ConfettiView), `Models/AssetAnalysis.swift`,
`Services/AnalysisCache.swift`, `Services/NotificationService.swift`, `Shared/GameSnapshot.swift`,
`TrashPandaWidget/*` (бандл, provider, view, Info.plist), два `*.entitlements`.

**Переиспользую:** `PhotoLibraryService.estimatedByteSize`, `ClutterAnalyzer.featurePrint/sharpness/isBlurry`,
`CleanupOutcome`, `DOSRing`, `Theme`.

---

## Verification (шаг DO)

1. `xcodegen generate` — без ошибок спеки.
2. Сборка приложения: `xcodebuild -project TrashPanda.xcodeproj -scheme TrashPanda -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`.
3. Тесты движков: `xcodebuild test -project TrashPanda.xcodeproj -scheme TrashPanda -destination 'platform=iOS Simulator,name=<доступный симулятор>'` — все проходят, включая обновлённые Rank/Achievement.
4. Виджет: отдельная сборка таргета; при провале подписи — фиксирую отчётом, не считаю фичу закрытой.
5. Перечислю что проверил (сборка ✓, тесты ✓, нет хардкода секретов ✓, риск виджета зафиксирован).

**После этого — сдаю тебе на проверку** (не считаю задачу закрытой сам). По «окей»:
актуализирую заметки 03/04/06/07/08/10 в Obsidian, пишу релиз-ноут за сегодня, коммичу и пушу.
