import SwiftUI

public struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState

    @State private var selectedSubjectId: String = ""
    @State private var selectedDay: Int = 1
    @State private var selectedLessonIndex: Int = 1
    @State private var title: String = ""
    @State private var eventType: EventType = .sprawdzian
    @State private var eventDate: Date = Date()
    @State private var note: String = ""

    public init(appState: AppState, defaultDay: Int = 1) {
        self.appState = appState
        _selectedDay = State(initialValue: defaultDay)
        if let firstSub = appState.visibleSubjects.first {
            _selectedSubjectId = State(initialValue: firstSub.id)
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Informacje o wydarzeniu")) {
                    Picker("Typ wydarzenia", selection: $eventType) {
                        ForEach(EventType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("Tytuł (np. Dział 3: Funkcje)", text: $title)

                    Picker("Przedmiot", selection: $selectedSubjectId) {
                        ForEach(appState.visibleSubjects) { subject in
                            Text(subject.name).tag(subject.id)
                        }
                    }
                }

                Section(header: Text("Termin w planie lekcji")) {
                    DatePicker("Data", selection: $eventDate, displayedComponents: [.date])

                    Picker("Dzień tygodnia", selection: $selectedDay) {
                        Text("Poniedziałek").tag(1)
                        Text("Wtorek").tag(2)
                        Text("Środa").tag(3)
                        Text("Czwartek").tag(4)
                        Text("Piątek").tag(5)
                    }

                    Stepper("Numer lekcji: \(selectedLessonIndex)", value: $selectedLessonIndex, in: 1...9)
                }

                Section(header: Text("Dodatkowe notatki (opcjonalnie)")) {
                    TextField("Np. zabrać kalkulator, powtórzyć wzory", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Dodaj wydarzenie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        saveEvent()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || selectedSubjectId.isEmpty)
                }
            }
        }
    }

    private func saveEvent() {
        appState.addScheduleEvent(
            subjectId: selectedSubjectId,
            dayOfWeek: selectedDay,
            lessonIndex: selectedLessonIndex,
            title: title.trimmingCharacters(in: .whitespaces),
            type: eventType,
            date: eventDate,
            note: note.trimmingCharacters(in: .whitespaces)
        )
        dismiss()
    }
}
