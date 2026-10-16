import SwiftUI
import PhotosUI

public struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showingResetBgAlert: Bool = false
    @State private var showingTestNotificationAlert: Bool = false

    public var body: some View {
        NavigationStack {
            Form {
                // SEKCJA 1: PERSONALIZACJA WYGLĄDU I TŁA
                Section(header: Text("Personalizacja i Motyw")) {
                    Picker("Kolor przewodni", selection: $appState.selectedTheme) {
                        ForEach(AppThemeColor.allCases, id: \.self) { theme in
                            HStack {
                                Circle()
                                    .fill(theme.color)
                                    .frame(width: 14, height: 14)
                                Text(theme.rawValue)
                            }
                            .tag(theme)
                        }
                    }
                    .onChange(of: appState.selectedTheme) { _ in
                        appState.saveData()
                    }

                    // Wybór własnego zdjęcia jako tło
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            Label("Wybierz własne zdjęcie jako tło", systemImage: "photo.badge.plus")
                            Spacer()
                            if appState.backgroundImageData != nil {
                                Text("Ustawione")
                                    .font(.caption)
                                    .foregroundColor(appState.selectedTheme.color)
                            }
                        }
                    }
                    .onChange(of: selectedPhotoItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                await MainActor.run {
                                    appState.setBackgroundImage(data: data)
                                }
                            }
                        }
                    }

                    // Dodatkowe opcje tła jeśli ustawiono
                    if appState.backgroundImageData != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Przyciemnienie tła: \(Int(appState.backgroundDimOpacity * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $appState.backgroundDimOpacity, in: 0.1...0.85, step: 0.05)
                                .onChange(of: appState.backgroundDimOpacity) { _ in appState.saveData() }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Rozmycie tła: \(Int(appState.backgroundBlurRadius)) px")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $appState.backgroundBlurRadius, in: 0.0...15.0, step: 1.0)
                                .onChange(of: appState.backgroundBlurRadius) { _ in appState.saveData() }
                        }

                        Button(role: .destructive) {
                            showingResetBgAlert = true
                        } label: {
                            Label("Usuń własne tło", systemImage: "trash")
                        }
                    }
                }

                // SEKCJA 2: POWIADOMIENIA
                Section(header: Text("Powiadomienia"), footer: Text("Możesz zdecydować, o jakich zdarzeniach chcesz być powiadamiany na bieżąco.")) {
                    Toggle("Włącz powiadomienia", isOn: $appState.notificationSettings.isEnabled)
                        .onChange(of: appState.notificationSettings.isEnabled) { enabled in
                            if enabled {
                                NotificationManager.shared.requestPermission()
                            }
                            appState.saveData()
                        }

                    if appState.notificationSettings.isEnabled {
                        Toggle("Nowe oceny", isOn: $appState.notificationSettings.notifyGrades)
                            .onChange(of: appState.notificationSettings.notifyGrades) { _ in appState.saveData() }

                        Toggle("Nowe wiadomości", isOn: $appState.notificationSettings.notifyMessages)
                            .onChange(of: appState.notificationSettings.notifyMessages) { _ in appState.saveData() }

                        Toggle("Sprawdziany i kartkówki", isOn: $appState.notificationSettings.notifyExams)
                            .onChange(of: appState.notificationSettings.notifyExams) { _ in appState.saveData() }

                        Toggle("Koniec przerwy lekcyjnej", isOn: $appState.notificationSettings.notifyBreaks)
                            .onChange(of: appState.notificationSettings.notifyBreaks) { _ in appState.saveData() }

                        Button {
                            NotificationManager.shared.sendLocalNotification(
                                title: "Librus+: Test Powiadomień",
                                body: "Wszystko działa idealnie! Będziesz otrzymywać powiadomienia zgodnie z konfiguracją.",
                                delaySeconds: 2
                            )
                            showingTestNotificationAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(appState.selectedTheme.color)
                                Text("Wyślij testowe powiadomienie (za 2 sek.)")
                            }
                        }
                    }
                }

                // SEKCJA 3: ZARZĄDZANIE PRZEDMIOTAMI (UKRYWANIE NP. RELIGII)
                Section(
                    header: Text("Widoczność Przedmiotów"),
                    footer: Text("Wyłącz przedmioty, na które nie uczęszczasz (np. Religia, Etyka, WDŻ). Wyłączone przedmioty znikną z planu lekcji, ocen oraz frekwencji i nie będą wpływać na średnią ogólną.")
                ) {
                    ForEach(appState.subjects) { subject in
                        Toggle(isOn: Binding(
                            get: { !subject.isHidden },
                            set: { _ in appState.toggleSubjectHidden(id: subject.id) }
                        )) {
                            HStack {
                                Image(systemName: subject.icon)
                                    .foregroundColor(appState.selectedTheme.color)
                                    .frame(width: 24)
                                Text(subject.name)
                            }
                        }
                    }
                }

                // SEKCJA 4: O APLIKACJI I SIDELOAD
                Section(header: Text("Informacje")) {
                    HStack {
                        Text("Wersja aplikacji")
                        Spacer()
                        Text("1.0.0 (Librus+)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Docelowy iOS")
                        Spacer()
                        Text("iOS 18.3")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Tryb instalacji")
                        Spacer()
                        Text("Sideload / AltStore / Sideloadly")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Ustawienia")
            .alert("Zresetować tło?", isPresented: $showingResetBgAlert) {
                Button("Usuń tło", role: .destructive) {
                    appState.setBackgroundImage(data: nil)
                }
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Przywróci to domyślne tło systemowe.")
            }
            .alert("Wysłano testowe powiadomienie", isPresented: $showingTestNotificationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Zablokuj ekran lub przejdź do ekranu głównego, aby zobaczyć powiadomienie na banerze.")
            }
            .customAppBackground(appState: appState)
        }
    }
}
