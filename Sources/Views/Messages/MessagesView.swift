import SwiftUI

public struct MessagesView: View {
    @ObservedObject var appState: AppState
    @State private var selectedBox: Int = 0 // 0 = Odebrane, 1 = Wysłane
    @State private var showingCompose: Bool = false
    @State private var selectedMessage: SchoolMessage? = nil
    @State private var searchText: String = ""

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("Skrzynka", selection: $selectedBox) {
                    Text("Odebrane (\(appState.unreadMessagesCount))").tag(0)
                    Text("Wysłane").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Lista wiadomości
                let filteredMessages = appState.messages
                    .filter { msg in
                        if selectedBox == 0 {
                            return !msg.isSentByUser
                        } else {
                            return msg.isSentByUser
                        }
                    }
                    .filter { msg in
                        if searchText.isEmpty { return true }
                        return msg.subject.localizedCaseInsensitiveContains(searchText) ||
                               msg.sender.localizedCaseInsensitiveContains(searchText) ||
                               msg.body.localizedCaseInsensitiveContains(searchText)
                    }

                if filteredMessages.isEmpty {
                    emptyMessagesView
                } else {
                    List {
                        ForEach(filteredMessages) { msg in
                            Button {
                                selectedMessage = msg
                            } label: {
                                messageRow(message: msg)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Szukaj w wiadomościach...")
            .navigationTitle("Wiadomości")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        // Przycisk do symulacji nowej wiadomości od nauczyciela (dla testu powiadomień)
                        Button {
                            appState.simulateIncomingMessage()
                        } label: {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 16))
                        }

                        Button {
                            showingCompose = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCompose) {
                ComposeMessageView(appState: appState)
            }
            .sheet(item: $selectedMessage) { msg in
                MessageDetailView(appState: appState, message: msg)
            }
            .customAppBackground(appState: appState)
        }
    }

    private func messageRow(message: SchoolMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Wskaźnik nieprzeczytanej wiadomości
            if !message.isRead && !message.isSentByUser {
                Circle()
                    .fill(appState.selectedTheme.color)
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)
            } else {
                Spacer()
                    .frame(width: 10)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.isSentByUser ? "Do: \(message.recipient)" : message.sender)
                        .font(.headline)
                        .fontWeight(message.isRead ? .semibold : .bold)
                        .lineLimit(1)

                    Spacer()

                    Text(message.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(message.subject)
                    .font(.subheadline)
                    .fontWeight(message.isRead ? .regular : .semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(message.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyMessagesView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            Text("Brak wiadomości w tym folderze")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
