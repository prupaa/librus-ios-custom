import SwiftUI

public struct TimetableView: View {
    @ObservedObject var appState: AppState
    @State private var selectedDay: Int = 1
    @State private var showingAddEvent: Bool = false

    private let days = [
        (index: 1, name: "Poniedziałek", short: "Pn"),
        (index: 2, name: "Wtorek", short: "Wt"),
        (index: 3, name: "Środa", short: "Śr"),
        (index: 4, name: "Czwartek", short: "Czw"),
        (index: 5, name: "Piątek", short: "Pt")
    ]

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selektor Dni Tygodnia
                daySelectorBar

                // Lista lekcji dla wybranego dnia
                ScrollView {
                    LazyVStack(spacing: 12) {
                        let dailyLessons = appState.lessons
                            .filter { $0.dayOfWeek == selectedDay }
                            .filter { lesson in
                                // Ukrywamy lekcje, jeśli przedmiot został wyłączony w ustawieniach (np. Religia)
                                if let subj = appState.subjects.first(where: { $0.id == lesson.subjectId }) {
                                    return !subj.isHidden
                                }
                                return true
                            }
                            .sorted { $0.lessonIndex < $1.lessonIndex }

                        if dailyLessons.isEmpty {
                            emptyDayView
                        } else {
                            ForEach(Array(dailyLessons.enumerated()), id: \.element.id) { index, lesson in
                                lessonCard(lesson: lesson)

                                // Wyświetlanie informacji o przerwie (jeśli to nie jest ostatnia lekcja)
                                if index < dailyLessons.count - 1 && lesson.breakAfterMinutes > 0 {
                                    breakIndicator(minutes: lesson.breakAfterMinutes)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Plan Lekcji")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddEvent = true
                    } label: {
                        Label("Dodaj wydarzenie", systemImage: "plus.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventSheet(appState: appState, defaultDay: selectedDay)
            }
            .customAppBackground(appState: appState)
        }
    }

    // MARK: - Subviews

    private var daySelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.index) { day in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDay = day.index
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.short)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(day.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            selectedDay == day.index
                                ? appState.selectedTheme.color
                                : Color(uiColor: .secondarySystemGroupedBackground)
                        )
                        .foregroundColor(selectedDay == day.index ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(selectedDay == day.index ? 0.15 : 0.03), radius: 3, y: 1)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func lessonCard(lesson: Lesson) -> some View {
        let subject = appState.subjects.first(where: { $0.id == lesson.subjectId })
        let subjectTitle = subject?.name ?? "Lekcja"
        let teacherName = lesson.teacher.isEmpty ? (subject?.teacher ?? "") : lesson.teacher
        let roomName = lesson.room.isEmpty ? (subject?.defaultRoom ?? "") : lesson.room

        // Sprawdzamy czy dla tej lekcji są przypisane wydarzenia (sprawdzian, kartkówka)
        let matchingEvents = appState.events.filter {
            $0.dayOfWeek == selectedDay && $0.lessonIndex == lesson.lessonIndex
        }

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // Numer lekcji i godziny
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(lesson.lessonIndex). lekcja")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(appState.selectedTheme.color)
                    Text("\(lesson.startTime) - \(lesson.endTime)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(width: 90, alignment: .leading)

                Divider()
                    .frame(height: 38)

                // Nazwa przedmiotu, sala, nauczyciel
                VStack(alignment: .leading, spacing: 4) {
                    Text(subjectTitle)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        Label(teacherName, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        if !roomName.isEmpty {
                            Label("s. \(roomName)", systemImage: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }

            // Wyświetlanie wydarzeń użytkownika pod daną lekcją
            if !matchingEvents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(matchingEvents) { event in
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(event.type.rawValue): \(event.title)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                if !event.note.isEmpty {
                                    Text(event.note)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                withAnimation {
                                    appState.removeScheduleEvent(id: event.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }

    private func breakIndicator(minutes: Int) -> some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.caption2)
                Text("Przerwa: \(minutes) min")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .foregroundColor(.secondary)
            .clipShape(Capsule())

            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.vertical, 2)
    }

    private var emptyDayView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Brak zaplanowanych lekcji na ten dzień")
                .font(.headline)
            Text("Odpocznij lub dodaj własne zajęcia!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
