import SwiftUI
import Charts

public struct AttendanceView: View {
    @ObservedObject var appState: AppState
    @State private var selectedMonth: MonthlyAttendance? = nil
    @State private var selectedSubjectForDetail: Subject? = nil

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // KARTA GŁÓWNA - AKTUALNA FREKWENCJA OGÓLNA
                    overallAttendanceCard

                    // WYKRES LINIOWY NA KAŻDY MIESIĄC SZKOŁY
                    monthlyChartCard

                    // STATYSTYKI SPÓŹNIEŃ I NIEOBECNOŚCI
                    statisticsSummaryGrid

                    // PRZEDMIOTY ZE SWOJĄ FREKWENCJĄ (W STYLU OCEN)
                    subjectsAttendanceSection
                }
                .padding()
            }
            .navigationTitle("Frekwencja")
            .sheet(item: $selectedSubjectForDetail) { subj in
                SubjectAttendanceDetailView(appState: appState, subject: subj)
            }
            .customAppBackground(appState: appState)
        }
    }

    // MARK: - Karta Ogólnej Frekwencji
    private var overallAttendanceCard: some View {
        let percent = appState.overallAttendancePercentage

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AKTUALNA FREKWENCJA CAŁKOWITA")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.85))

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", percent))
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Text("%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.85))
                }

                Text(percent >= 50.0 ? "Status: Spełniony warunek klasyfikacji (>50%)" : "Uwaga: Zagrożenie nieklasyfikacją (<50%)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(percent >= 50.0 ? .white.opacity(0.8) : .yellow)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 68, height: 68)

                Circle()
                    .trim(from: 0, to: CGFloat(min(percent / 100.0, 1.0)))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 68, height: 68)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "percent")
                    .font(.system(size: 20, weight: .bold))
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

    // MARK: - Wykres Liniowy na Każdy Miesiąc
    private var monthlyChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Frekwencja miesięczna")
                        .font(.headline)
                    Text("Wykres zmian frekwencji w trakcie roku szkolnego")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let sel = selectedMonth {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(sel.month)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(appState.selectedTheme.color)
                        Text(String(format: "%.1f%%", sel.percentage))
                            .font(.subheadline)
                            .fontWeight(.heavy)
                    }
                }
            }

            // Swift Charts Line & Point Chart
            Chart {
                ForEach(appState.monthlyAttendance) { item in
                    LineMark(
                        x: .value("Miesiąc", item.month),
                        y: .value("Frekwencja", item.percentage)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(appState.selectedTheme.color)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("Miesiąc", item.month),
                        y: .value("Frekwencja", item.percentage)
                    )
                    .foregroundStyle(appState.selectedTheme.color)
                    .symbolSize(selectedMonth?.month == item.month ? 80 : 40)
                }

                // Linia ostrzegawcza 50%
                RuleMark(y: .value("Próg klasyfikacji", 50))
                    .foregroundStyle(.red.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Próg 50%")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    }
            }
            .chartYScale(domain: 40...100)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel() {
                        if let str = value.as(String.self) {
                            Text(String(str.prefix(3))) // Wrk, Paź, Lis...
                                .font(.system(size: 10))
                        }
                    }
                }
            }
            .frame(height: 190)
            .padding(.top, 8)

            // Klikalna lista miesięcy do sprawdzenia dokładnej frekwencji
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appState.monthlyAttendance) { item in
                        Button {
                            withAnimation {
                                selectedMonth = item
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(item.month)
                                    .font(.caption2)
                                Text(String(format: "%.1f%%", item.percentage))
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedMonth?.month == item.month ? appState.selectedTheme.color.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground))
                            .foregroundColor(selectedMonth?.month == item.month ? appState.selectedTheme.color : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedMonth?.month == item.month ? appState.selectedTheme.color : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Siatka Statystyk
    private var statisticsSummaryGrid: some View {
        let stats = appState.attendanceStats

        return VStack(alignment: .leading, spacing: 10) {
            Text("Statystyka godzinowa")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statBox(title: "Spóźnienia", value: "\(stats.lates)", subtext: "\(stats.latesExcused) usprawiedliwionych", icon: "clock.fill", color: .orange)
                statBox(title: "Nieobecności", value: "\(stats.absences)", subtext: "\(stats.absencesExcused) usprawiedliwionych", icon: "xmark.circle.fill", color: .red)
                statBox(title: "Zwolnienia", value: "\(stats.releases)", subtext: "Usprawiedliwione", icon: "arrowshape.turn.up.right.fill", color: .blue)
                statBox(title: "Spóźn. uspraw.", value: "\(stats.latesExcused)", subtext: "Zaakceptowane", icon: "checkmark.circle.fill", color: .green)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }

    private func statBox(title: String, value: String, subtext: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text(subtext)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Przedmioty i Frekwencja w Stylu Ocen
    private var subjectsAttendanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frekwencja z przedmiotów")
                .font(.headline)

            Text("Dotknij przedmiotu, aby zobaczyć szczegółową historię wpisów i nieobecności")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(appState.visibleSubjects) { subject in
                let percent = appState.attendancePercentage(for: subject.id)

                Button {
                    selectedSubjectForDetail = subject
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: subject.icon)
                            .font(.system(size: 20))
                            .foregroundColor(appState.selectedTheme.color)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(subject.name)
                                .font(.headline)
                                .foregroundColor(.primary)

                            // Pasek postępu frekwencji
                            ProgressView(value: min(percent / 100.0, 1.0))
                                .tint(percent >= 50.0 ? appState.selectedTheme.color : .red)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.1f%%", percent))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(percent >= 50.0 ? .primary : .red)

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
