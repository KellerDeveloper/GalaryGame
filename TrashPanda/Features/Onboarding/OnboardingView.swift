import SwiftUI

/// First-run screen that explains the game and requests photo access.
struct OnboardingView: View {
    @Bindable var photos: PhotoLibraryService
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 72))
                .foregroundStyle(Theme.accent)

            VStack(spacing: 12) {
                Text("Наведи цифровой порядок")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Убирай галерею как игру: получай очки и уровни за удаление дубликатов, размытых и скриншотов — и за раскладку фото по альбомам.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 14) {
                feature("lock.shield", "Приватно", "Фото анализируются только на устройстве и никуда не отправляются.")
                feature("wand.and.stars", "Умный поиск", "Находим дубликаты, размытые кадры и скриншоты.")
                feature("trophy", "Награды", "Очки, стрики, уровни и ачивки за порядок.")
            }
            .padding(.horizontal, 24)

            Spacer()

            if photos.authState == .denied {
                Text("Доступ к фото запрещён. Разреши его в Настройках, чтобы играть.")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task {
                    requesting = true
                    await photos.requestAuthorization()
                    requesting = false
                }
            } label: {
                Text(requesting ? "Запрашиваем…" : "Разрешить доступ к фото")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
            .disabled(requesting)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func feature(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
