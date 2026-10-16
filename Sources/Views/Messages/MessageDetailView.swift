import SwiftUI

public struct MessageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    let message: SchoolMessage
    @State private var showingReplySheet: Bool = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Nagłówek wiadomości
                    VStack(alignment: .leading, spacing: 8) {
                        Text(message.subject)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Od:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(message.sender)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }

                                HStack {
                                    Text("Do:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(message.recipient)
                                        .font(.caption)
                                }
                            }

                            Spacer()

                            Text(message.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Treść
                    VStack(alignment: .leading, spacing: 12) {
                        Text(message.body)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Przycisk Odpowiedz (jeśli wiadomość jest odebrana od nauczyciela)
                    if !message.isSentByUser {
                        Button {
                            showingReplySheet = true
                        } label: {
                            HStack {
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                Text("Odpowiedz na wiadomość")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(appState.selectedTheme.color)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle("Wiadomość")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
            .sheet(isPresented: $showingReplySheet) {
                ComposeMessageView(
                    appState: appState,
                    initialRecipient: message.sender,
                    initialSubject: message.subject.hasPrefix("Re: ") ? message.subject : "Re: \(message.subject)"
                )
            }
        }
        .onAppear {
            appState.markMessageAsRead(id: message.id)
        }
    }
}
