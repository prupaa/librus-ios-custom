import SwiftUI

public struct GradesView: View {
    @ObservedObject var appState: AppState
    @State private var showingAddGrade: Bool = false
    @State private var selectedGradeForDetail: Grade? = nil
    @State private var subjectToHide: Subject? = nil
    @State private var showingHideAlert: Bool = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // KARTA GŁÓWNA ZE ŚREDNIĄ ZE WSZYSTKICH PRZEDMIOTÓW
                    overallGpaCard

                    // LISTA PRZEDMIOTÓW Z OCENAMI I ŚREDNIMI
                    ForEach(appState.visibleSubjects) { subject in
                        subjectGradesCard(subject: subject)
                    }
                }
                .padding()
            }
            .navigationTitle("Oceny")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGrade = true
                    } label: {
                        Label("Dodaj ocenę", systemImage: "plus.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showingAddGrade) {
                AddGradeSheet(appState: appState)
            }
            .sheet(item: $selectedGradeForDetail) { grade in
                gradeDetailSheet(grade: grade)
            }
            .alert("Ukryć przedmiot?", isPresented: $showingHideAlert, presenting: subjectToHide) { subj in
                Button("Ukryj \(subj.name)", role: .destructive) {
                    withAnimation {
                        appState.toggleSubjectHidden(id: subj.id)
                    }
                }
                Button("Anuluj", role: .cancel) {}
            } message: { subj in
                Text("Przedmiot nie będzie wliczany do średniej ogólnej ani wyświetlany w planie lekcji i frekwencji. Możesz go w każdej chwili przywrócić w Ustawieniach.")
            }
            .customAppBackground(appState: appState)
        }
    }

    // MARK: - Karta Średniej Ogólnej
    private var overallGpaCard: some View {
        let gpa = appState.overallGPA

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ŚREDNIA ZE WSZYSTKICH PRZEDMIOTÓW")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.85))

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(String(format: "%.2f", gpa))
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Text("/ 6.00")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                }

                Text("\(appState.visibleSubjects.count) aktywnych przedmiotów")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 68, height: 68)

                Image(systemName: gpa >= 4.75 ? "rosette" : "graduationcap.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [appState.selectedTheme.color, appState.selectedTheme.color.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: appState.selectedTheme.color.opacity(0.3), radius: 8, y: 4)
    }

    // MARK: - Karta Pojedynczego Przedmiotu
    private func subjectGradesCard(subject: Subject) -> some View {
        let subjectGrades = appState.grades.filter { $0.subjectId == subject.id }
        let avg = appState.average(for: subject.id)

        return VStack(alignment: .leading, spacing: 12) {
            // Nagłówek przedmiotu
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subject.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subject.teacher)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Przycisk ukrycia przedmiotu (np. Religia)
                Menu {
                    Button(role: .destructive) {
                        subjectToHide = subject
                        showingHideAlert = true
                    } label: {
                        Label("Ukryj przedmiot (\(subject.name))", systemImage: "eye.slash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }

            Divider()

            // Oceny
            if subjectGrades.isEmpty {
                Text("Brak wpisanych ocen")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(subjectGrades) { grade in
                            Button {
                                selectedGradeForDetail = grade
                            } label: {
                                gradeBadge(grade: grade)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // Średnia przedmiotu
            HStack {
                Text("Średnia ważona:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if let avg = avg {
                    Text(String(format: "%.2f", avg))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(averageColor(avg))
                } else {
                    Text("-")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Wygląd Oceny (Pill Badge)
    private func gradeBadge(grade: Grade) -> some View {
        VStack(spacing: 2) {
            Text(grade.displayValue)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(gradeTextColor(grade.value))

            Text("w: \(grade.weight)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 42, minHeight: 46)
        .padding(.horizontal, 6)
        .background(gradeBackgroundColor(grade.value))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(gradeTextColor(grade.value).opacity(0.3), lineWidth: 1)
        )
    }

    private func gradeTextColor(_ val: Double) -> Color {
        if val >= 4.5 { return Color.green }
        if val >= 3.0 { return Color.blue }
        if val >= 2.0 { return Color.orange }
        return Color.red
    }

    private func gradeBackgroundColor(_ val: Double) -> Color {
        gradeTextColor(val).opacity(0.12)
    }

    private func averageColor(_ val: Double) -> Color {
        if val >= 4.75 { return .green }
        if val >= 3.75 { return appState.selectedTheme.color }
        if val >= 2.50 { return .orange }
        return .red
    }

    // MARK: - Arkusz szczegółów oceny
    private func gradeDetailSheet(grade: Grade) -> some View {
        NavigationStack {
            List {
                Section(header: Text("Ocena")) {
                    HStack {
                        Text("Wartość")
                        Spacer()
                        Text(grade.displayValue)
                            .font(.headline)
                            .foregroundColor(gradeTextColor(grade.value))
                    }
                    HStack {
                        Text("Kategoria")
                        Spacer()
                        Text(grade.category)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Waga")
                        Spacer()
                        Text("\(grade.weight)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Data wystawienia")
                        Spacer()
                        Text(grade.date.formatted(date: .long, time: .omitted))
                            .foregroundColor(.secondary)
                    }
                }

                if !grade.comment.isEmpty {
                    Section(header: Text("Komentarz nauczyciela")) {
                        Text(grade.comment)
                    }
                }
            }
            .navigationTitle("Szczegóły oceny")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zamknij") {
                        selectedGradeForDetail = nil
                    }
                }
            }
        }
    }
}
