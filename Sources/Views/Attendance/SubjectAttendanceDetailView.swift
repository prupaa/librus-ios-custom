import SwiftUI

public struct SubjectAttendanceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    let subject: Subject

    public var body: some View {
        NavigationStack {
            let records = appState.attendanceRecords.filter { $0.subjectId == subject.id }
            let percent = appState.attendancePercentage(for: subject.id)

            List {
                Section(header: Text("Podsumowanie frekwencji")) {
                    HStack {
                        Text("Frekwencja z przedmiotu")
                        Spacer()
                        Text(String(format: "%.1f%%", percent))
                            .font(.headline)
                            .foregroundColor(percent >= 50.0 ? .primary : .red)
                    }

                    HStack {
                        Text("Nauczyciel")
                        Spacer()
                        Text(subject.teacher)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Wszystkich sprawdzonych godzin")
                        Spacer()
                        Text("\(records.count)")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Zestawienie godzin")) {
                    let presentCount = records.filter { $0.status == .present }.count
                    let latesCount = records.filter { $0.status == .late || $0.status == .lateExcused }.count
                    let absentCount = records.filter { $0.status == .absent || $0.status == .absentExcused }.count
                    let releaseCount = records.filter { $0.status == .released }.count

                    HStack {
                        Label("Obecności", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                        Text("\(presentCount)")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Label("Spóźnienia", systemImage: "clock.badge.exclamationmark.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        Text("\(latesCount)")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Label("Nieobecności", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Spacer()
                        Text("\(absentCount)")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Label("Zwolnienia", systemImage: "arrowshape.turn.up.right.fill")
                            .foregroundColor(.blue)
                        Spacer()
                        Text("\(releaseCount)")
                            .fontWeight(.semibold)
                    }
                }

                Section(header: Text("Szczegółowa historia wpisów")) {
                    if records.isEmpty {
                        Text("Brak wpisów frekwencji")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(records) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(record.status.rawValue)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(record.status.badgeColor.opacity(0.15))
                                        .foregroundColor(record.status.badgeColor)
                                        .clipShape(Capsule())

                                    Spacer()

                                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text(record.topic)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(subject.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") {
                        dismiss()
                    }
                }
            }
        }
    }
}
