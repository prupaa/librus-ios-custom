import SwiftUI

public struct AddGradeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState

    @State private var selectedSubjectId: String = ""
    @State private var gradeValue: Double = 5.0
    @State private var displayValue: String = "5"
    @State private var weight: Int = 2
    @State private var category: String = "Sprawdzian"
    @State private var comment: String = ""

    private let predefinedGrades = [
        ("1", 1.0), ("1+", 1.5),
        ("2", 2.0), ("2+", 2.5),
        ("3", 3.0), ("3+", 3.5),
        ("4", 4.0), ("4+", 4.5),
        ("5", 5.0), ("5+", 5.5),
        ("6", 6.0)
    ]

    private let categories = ["Sprawdzian", "Kartkówka", "Odpowiedź ustna", "Praca klasowa", "Aktywność", "Projekt", "Zadanie domowe"]

    public init(appState: AppState, defaultSubjectId: String? = nil) {
        self.appState = appState
        if let def = defaultSubjectId {
            _selectedSubjectId = State(initialValue: def)
        } else if let first = appState.visibleSubjects.first {
            _selectedSubjectId = State(initialValue: first.id)
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Przedmiot i ocena")) {
                    Picker("Przedmiot", selection: $selectedSubjectId) {
                        ForEach(appState.visibleSubjects) { subj in
                            Text(subj.name).tag(subj.id)
                        }
                    }

                    Picker("Ocena", selection: $displayValue) {
                        ForEach(predefinedGrades, id: \.0) { item in
                            Text(item.0).tag(item.0)
                        }
                    }
                    .onChange(of: displayValue) { newValue in
                        if let match = predefinedGrades.first(where: { $0.0 == newValue }) {
                            gradeValue = match.1
                        }
                    }

                    Stepper("Waga oceny: \(weight)", value: $weight, in: 1...6)
                }

                Section(header: Text("Kategoria")) {
                    Picker("Kategoria", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }

                    TextField("Komentarz (np. Dział 2, Zadania z gwiazdką)", text: $comment)
                }
            }
            .navigationTitle("Wpisz nową ocenę")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dodaj") {
                        appState.addGrade(
                            subjectId: selectedSubjectId,
                            value: gradeValue,
                            displayValue: displayValue,
                            weight: weight,
                            category: category,
                            comment: comment
                        )
                        dismiss()
                    }
                    .disabled(selectedSubjectId.isEmpty)
                }
            }
        }
    }
}
