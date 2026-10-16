import SwiftUI

public struct ComposeMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState

    @State private var recipient: String = ""
    @State private var subject: String = ""
    @State private var bodyText: String = ""

    public init(appState: AppState, initialRecipient: String = "", initialSubject: String = "") {
        self.appState = appState
        _recipient = State(initialValue: initialRecipient)
        _subject = State(initialValue: initialSubject)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Adresat")) {
                    if recipient.isEmpty {
                        Picker("Wybierz nauczyciela", selection: $recipient) {
                            Text("Wybierz...").tag("")
                            ForEach(appState.visibleSubjects, id: \.teacher) { subj in
                                Text("\(subj.teacher) (\(subj.name))").tag(subj.teacher)
                            }
                            Text("Sekretariat Szkoły").tag("Sekretariat Szkoły")
                            Text("Dyrekcja").tag("Dyrekcja")
                        }
                    } else {
                        TextField("Odbiorca", text: $recipient)
                    }
                }

                Section(header: Text("Temat")) {
                    TextField("Wpisz temat wiadomości...", text: $subject)
                }

                Section(header: Text("Treść wiadomości")) {
                    TextField("Napisz wiadomość do nauczyciela...", text: $bodyText, axis: .vertical)
                        .lineLimit(6...12)
                }
            }
            .navigationTitle("Nowa wiadomość")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Wyślij") {
                        appState.sendMessage(
                            recipient: recipient.isEmpty ? "Sekretariat" : recipient,
                            subject: subject.trimmingCharacters(in: .whitespaces).isEmpty ? "(Brak tematu)" : subject,
                            body: bodyText
                        )
                        dismiss()
                    }
                    .disabled(bodyText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
