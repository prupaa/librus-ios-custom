import SwiftUI
import WebKit

public struct LibrusLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @ObservedObject private var librusService = LibrusService.shared

    @State private var loginText: String = ""
    @State private var passwordText: String = ""
    @State private var isShowingWebView: Bool = false
    @State private var isLoggingIn: Bool = false
    @State private var errorMessage: String? = nil

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo & Nagłówek
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(appState.selectedTheme.color.opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 42))
                                .foregroundColor(appState.selectedTheme.color)
                        }

                        Text("Połącz z kontem Librus")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Zaloguj się danymi do systemu Synergia lub Konta Librus, aby pobierać swoje prawdziwe oceny, frekwencję i plan.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 16)

                    // Formularz Logowania
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Login lub E-mail")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                TextField("Login z Synergii lub e-mail", text: $loginText)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Hasło")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                SecureField("Twoje hasło", text: $passwordText)
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Przycisk Zaloguj
                        Button {
                            performLogin()
                        } label: {
                            HStack {
                                if isLoggingIn {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Zaloguj do Synergii")
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(appState.selectedTheme.color)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isLoggingIn || loginText.isEmpty || passwordText.isEmpty)

                        // Alternatywna metoda: Logowanie przez stronę www
                        Button {
                            isShowingWebView = true
                        } label: {
                            HStack {
                                Image(systemName: "safari")
                                Text("Zaloguj przez Portal Librus (Web)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(appState.selectedTheme.color)
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // Informacja o bezpieczeństwie
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("Twoje dane logowania są przetwarzane wyłącznie lokalnie w Twoim telefonie i nie trafiają na żadne zewnętrzne serwery.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Konto Librus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingWebView) {
                LibrusWebLoginSheet(appState: appState) {
                    dismiss()
                }
            }
        }
    }

    private func performLogin() {
        isLoggingIn = true
        errorMessage = nil

        Task {
            let success = await librusService.login(login: loginText, password: passwordText)
            await MainActor.run {
                isLoggingIn = false
                if success {
                    dismiss()
                } else {
                    errorMessage = librusService.errorMessage ?? "Błąd logowania. Sprawdź poprawność danych."
                }
            }
        }
    }
}

// MARK: - Arkusz Logowania przez Oficjalny Portal Librus (WebKit)
public struct LibrusWebLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    var onLoginSuccess: () -> Void

    public var body: some View {
        NavigationStack {
            LibrusWebView(onSuccess: {
                Task {
                    _ = await LibrusService.shared.login(login: "Uczeń Librus", password: "authenticated_via_web")
                    onLoginSuccess()
                    dismiss()
                }
            })
            .navigationTitle("Logowanie Librus Portal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
        }
    }
}

public struct LibrusWebView: UIViewRepresentable {
    var onSuccess: () -> Void

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        if let url = URL(string: "https://portal.librus.pl/rodzina/synergia/loguj") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: LibrusWebView

        init(_ parent: LibrusWebView) {
            self.parent = parent
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url?.absoluteString {
                // Po udanym zalogowaniu Librus przekierowuje do synergia.librus.pl lub panelu ucznia
                if url.contains("synergia.librus.pl") && !url.contains("loguj") {
                    parent.onSuccess()
                }
            }
        }
    }
}
