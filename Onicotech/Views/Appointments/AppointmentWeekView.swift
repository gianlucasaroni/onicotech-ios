import SwiftUI
import Combine

enum WeekDensityMode: String, CaseIterable, Identifiable {
    case twoDays = "2gg"
    case workWeek = "Settimana lavorativa"
    case fullWeek = "Settimana"
    
    var id: String { rawValue }
    
    var visibleDaysCount: Int {
        switch self {
        case .twoDays:
            return 2
        case .workWeek:
            return 5
        case .fullWeek:
            return 7
        }
    }
}

struct AppointmentWeekView: View {
    @Bindable var viewModel: AppointmentViewModel
    @EnvironmentObject var salonManager: SalonManager
    
    var onAddAppointment: ((Date, Date) -> Void)? = nil
    
    @State private var selectedAppointment: Appointment?
    @State private var showingDeleteAlert = false
    @State private var appointmentToDelete: Appointment?
    
    @AppStorage("weekDensityMode") private var densityMode: WeekDensityMode = .twoDays
    
    @State private var scrollOffsetX: CGFloat = 0
    @State private var timelineWidth: CGFloat = 390
    @State private var salonBusinessHours: [BusinessHourItem] = []
    @State private var anchorMonday: Date = AppointmentWeekView.mondayOfWeek(containing: .now)
    @State private var scrolledDayID: Date? = AppointmentWeekView.startOfDay(.now)
    @State private var scrolledWeekID: Date? = AppointmentWeekView.mondayOfWeek(containing: .now)
    @State private var miniStripWeekID: Date? = AppointmentWeekView.mondayOfWeek(containing: .now)
    @State private var lastScrollDrivenDate: Date? = nil
    
    private let weeksRadius: Int = 12 // 25 continuous weeks (175 days)
    private let hourHeight: CGFloat = 64.0
    private let timeColWidth: CGFloat = 44.0
    private let headerHeight: CGFloat = 46.0
    private let separatorWidth: CGFloat = 1.0

    private static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private static func mondayOfWeek(containing date: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let monday = cal.date(from: comps) ?? date
        return Calendar.current.startOfDay(for: monday)
    }

    private var timelineWeekMondays: [Date] {
        let cal = Calendar.current
        return (-weeksRadius...weeksRadius).compactMap { offset in
            cal.date(byAdding: .day, value: offset * 7, to: anchorMonday)
        }
    }

    private var timelineDays: [Date] {
        let cal = Calendar.current
        let totalDays = (weeksRadius * 2 + 1) * 7
        let startOffset = -weeksRadius * 7
        return (0..<totalDays).compactMap { idx in
            cal.date(byAdding: .day, value: startOffset + idx, to: anchorMonday)
        }
    }

    private func daysOfWeek(starting monday: Date) -> [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }
    
    // Dynamic grid start and end hours based on week appointments
    private var minHour: Int {
        let apptHours = viewModel.appointments.map { $0.startMinutes / 60 }
        let earliest = apptHours.min() ?? 8
        return max(6, min(8, earliest))
    }
    
    private var maxHour: Int {
        let apptHours = viewModel.appointments.map { ($0.endMinutes + 59) / 60 }
        let latest = apptHours.max() ?? 20
        return min(23, max(20, latest))
    }
    
    private var totalGridMinutes: Int {
        (maxHour - minHour) * 60
    }
    
    private var totalGridHeight: CGFloat {
        CGFloat(maxHour - minHour) * hourHeight
    }
    
    private var pixelsPerMinute: CGFloat {
        hourHeight / 60.0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. Top Controls Bar (Month Navigation & [ 2gg | 3gg | Settimana ])
            topControlsBar
                .background(Color.systemBackgroundCompat)
                .zIndex(10)
            
            // MARK: - 2. Apple Calendar 7-Day Mini Strip (Native Paging Across Weeks)
            weekDaysMiniStrip
                .background(Color.systemBackgroundCompat)
                .zIndex(9)
            
            Divider()
            
            // MARK: - 3. Time Grid Area
            if viewModel.isLoading && !viewModel.hasLoadedOnce && viewModel.appointments.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Caricamento appuntamenti...")
                    Spacer()
                }
            } else {
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let availableWidth = max(100, totalWidth - timeColWidth - separatorWidth)
                    
                    let colCount: CGFloat = CGFloat(densityMode.visibleDaysCount)
                    let colWidth: CGFloat = densityMode == .fullWeek
                        ? (availableWidth - separatorWidth * (colCount - 1)) / colCount
                        : floor((availableWidth - separatorWidth * (colCount - 1)) / colCount)
                    
                    VStack(spacing: 0) {
                        // MARK: - Sticky Day Headers Strip (1:1 Locked to Horizontal Scroll)
                        stickyDayHeaders(colWidth: colWidth, availableWidth: availableWidth)
                            .background(Color.systemBackgroundCompat)
                            .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
                            .zIndex(8)
                        
                        Divider()
                        
                        // MARK: - Vertical Scrollable Timeline Body
                        ScrollView([.vertical]) {
                            HStack(alignment: .top, spacing: 0) {
                                // Sticky Left Time Column (08:00 to 20:00)
                                timeColumn
                                    .frame(width: timeColWidth)
                                    .background(Color.systemBackgroundCompat)
                                
                                // Vertical Separator
                                verticalSeparator
                                
                                // Native Continuous Multi-Week Horizontal Timeline
                                if densityMode == .fullWeek {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        fullWeekPagesContent(colWidth: colWidth, pageWidth: availableWidth)
                                            .scrollTargetLayout()
                                    }
                                    .scrollTargetBehavior(.paging)
                                    .scrollPosition(id: $scrolledWeekID, anchor: .leading)
                                    .frame(width: availableWidth)
                                    .onScrollGeometryChange(for: CGFloat.self) { geo in
                                        geo.contentOffset.x
                                    } action: { _, newOffset in
                                        scrollOffsetX = newOffset
                                    }
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        continuousDaysContent(colWidth: colWidth)
                                            .scrollTargetLayout()
                                    }
                                    .scrollTargetBehavior(.viewAligned)
                                    .scrollPosition(id: $scrolledDayID, anchor: .leading)
                                    .frame(width: availableWidth)
                                    .onScrollGeometryChange(for: CGFloat.self) { geo in
                                        geo.contentOffset.x
                                    } action: { _, newOffset in
                                        scrollOffsetX = newOffset
                                    }
                                }
                            }
                            .frame(width: totalWidth, alignment: .leading)
                            .frame(minHeight: totalGridHeight)
                        }
                        .refreshable {
                            Haptics.play(.light)
                            await viewModel.loadAppointments(salonId: salonManager.selectedSalonId)
                            Haptics.play(.success)
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { geo in
                    geo.size.width
                } action: { newWidth in
                    timelineWidth = newWidth
                }
            }
        }
        .onAppear {
            anchorMonday = Self.mondayOfWeek(containing: viewModel.selectedDate)
            syncScrollToSelectedDate(animated: false)
        }
        .onChange(of: scrolledDayID) { _, newDay in
            handleScrolledDayChanged(newDay)
        }
        .onChange(of: scrolledWeekID) { _, newMonday in
            handleScrolledWeekChanged(newMonday)
        }
        .onChange(of: miniStripWeekID) { _, newMonday in
            handleMiniStripWeekChanged(newMonday)
        }
        .onChange(of: viewModel.selectedDate) { _, newDate in
            let normalized = Self.startOfDay(newDate)
            if let driven = lastScrollDrivenDate, Calendar.current.isDate(driven, inSameDayAs: normalized) {
                lastScrollDrivenDate = nil
                return
            }
            syncScrollToSelectedDate(animated: true)
        }
        .onChange(of: densityMode) { _, _ in
            DispatchQueue.main.async {
                syncScrollToSelectedDate(animated: false)
            }
        }
        .task(id: salonManager.selectedSalonId) {
            await loadBusinessHours()
        }
        .sheet(item: $selectedAppointment) { appointment in
            NavigationStack {
                AppointmentDetailView(
                    appointmentId: appointment.id ?? UUID(),
                    initialAppointment: appointment,
                    viewModel: viewModel,
                    isModal: true
                )
            }
        }
        .alert("Eliminare l'appuntamento?", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                if let appt = appointmentToDelete, let id = appt.id {
                    Task {
                        let ok = await viewModel.deleteAppointment(id: id)
                        if ok { Haptics.play(.warning) }
                    }
                }
            }
        }
    }
    
    // MARK: - 1. Top Controls Bar
    private var topControlsBar: some View {
        HStack(spacing: 8) {
            // Week pagination (< >) & Month Title
            HStack(spacing: 4) {
                Button {
                    Haptics.play(.selection)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.changeWeek(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Settimana precedente")
                
                Text(monthYearTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Button {
                    Haptics.play(.selection)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.changeWeek(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Settimana successiva")
            }
            
            Spacer(minLength: 4)
            
            if viewModel.isLoading && viewModel.hasLoadedOnce {
                ProgressView()
                    .controlSize(.mini)
            }
            
            // "Oggi" button
            Button {
                Haptics.play(.selection)
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.goToToday()
                }
            } label: {
                Text("Oggi")
                    .font(.caption.bold())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(viewModel.isCurrentWeekToday ? Color.secondary.opacity(0.12) : Color.blue.opacity(0.15))
                    .foregroundStyle(viewModel.isCurrentWeekToday ? Color.secondary : Color.blue)
                    .clipShape(Capsule())
            }
            
            // View Density Selector Dropdown (2gg | Settimana lavorativa | Settimana)
            Menu {
                ForEach(WeekDensityMode.allCases) { mode in
                    Button {
                        Haptics.play(.selection)
                        densityMode = mode
                    } label: {
                        if densityMode == mode {
                            Label(mode.rawValue, systemImage: "checkmark")
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(densityMode.rawValue)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - 2. Apple Calendar 7-Day Mini Strip (Native Paging Across Weeks)
    private var weekDaysMiniStrip: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: timeColWidth + separatorWidth)
            
            GeometryReader { stripGeo in
                let pageWidth = max(100, stripGeo.size.width - 6)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(timelineWeekMondays, id: \.self) { monday in
                            let days = daysOfWeek(starting: monday)
                            HStack(spacing: 0) {
                                ForEach(days, id: \.self) { day in
                                    let isToday = Calendar.current.isDateInToday(day)
                                    let isSelected = Calendar.current.isDate(day, inSameDayAs: viewModel.selectedDate)
                                    let isVisible = isDayVisibleInTimeline(day: day)
                                    let apptCount = viewModel.appointments(for: day).count
                                    let dayNum = Calendar.current.component(.day, from: day)
                                    let dayLetter = shortSingleLetterDay(for: day)
                                    
                                    Button {
                                        Haptics.play(.selection)
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            viewModel.selectedDate = day
                                        }
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text(dayLetter)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(isToday ? Color.red : Color.secondary)
                                            
                                            ZStack {
                                                if isToday {
                                                    Circle()
                                                        .fill(Color.red)
                                                        .frame(width: 22, height: 22)
                                                } else if isSelected {
                                                    Circle()
                                                        .fill(Color.blue.opacity(0.18))
                                                        .frame(width: 22, height: 22)
                                                }
                                                
                                                Text("\(dayNum)")
                                                    .font(.system(size: 12, weight: isToday || isSelected ? .bold : .medium))
                                                    .foregroundStyle(isToday ? Color.white : (isSelected ? Color.blue : Color.primary))
                                            }
                                            .frame(height: 22)
                                            
                                            // Indicator dot
                                            Circle()
                                                .fill(apptCount > 0 ? (isToday ? Color.red : Color.blue) : Color.clear)
                                                .frame(width: 4, height: 4)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isVisible ? Color.secondary.opacity(0.08) : Color.clear)
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(width: pageWidth)
                            .id(monday)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $miniStripWeekID, anchor: .leading)
                .padding(.trailing, 6)
            }
            .frame(height: 48)
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - 3. Sticky Day Headers Strip (Synchronized 1:1 with columns below)
    private func stickyDayHeaders(colWidth: CGFloat, availableWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Fixed Corner Box above Time Column
            VStack(spacing: 2) {
                Spacer()
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("ORA")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(width: timeColWidth, height: headerHeight)
            .background(Color.systemBackgroundCompat)
            
            // Vertical Separator
            verticalSeparator
            
            // Synchronized sliding window of Day Headers (pixel-exact with scrollOffsetX)
            if densityMode == .fullWeek {
                let weeks = timelineWeekMondays
                let pageWidth = max(1, availableWidth)
                let currentPage = max(0, min(weeks.count - 1, Int(floor(scrollOffsetX / pageWidth))))
                let startPage = max(0, currentPage - 1)
                let endPage = min(weeks.count - 1, currentPage + 1)
                
                ZStack(alignment: .leading) {
                    ForEach(startPage...endPage, id: \.self) { pageIdx in
                        let weekDays = daysOfWeek(starting: weeks[pageIdx])
                        HStack(spacing: 0) {
                            ForEach(Array(weekDays.enumerated()), id: \.element) { idx, day in
                                dayHeaderCell(for: day, index: idx, width: colWidth)
                                    .frame(width: colWidth, height: headerHeight)
                                if idx < weekDays.count - 1 {
                                    verticalSeparator
                                }
                            }
                        }
                        .frame(width: availableWidth, height: headerHeight, alignment: .leading)
                        .offset(x: CGFloat(pageIdx) * availableWidth - scrollOffsetX)
                    }
                }
                .frame(width: availableWidth, height: headerHeight, alignment: .leading)
                .clipped()
            } else {
                let days = timelineDays
                let stepWidth = max(1, colWidth + separatorWidth)
                let firstIdx = max(0, min(days.count - 1, Int(floor(scrollOffsetX / stepWidth))))
                let startIdx = max(0, firstIdx - 1)
                let endIdx = min(days.count - 1, firstIdx + densityMode.visibleDaysCount + 1)
                
                ZStack(alignment: .leading) {
                    ForEach(startIdx...endIdx, id: \.self) { idx in
                        let day = days[idx]
                        HStack(spacing: 0) {
                            dayHeaderCell(for: day, index: idx, width: colWidth)
                                .frame(width: colWidth, height: headerHeight)
                            verticalSeparator
                        }
                        .offset(x: CGFloat(idx) * stepWidth - scrollOffsetX)
                    }
                }
                .frame(width: availableWidth, height: headerHeight, alignment: .leading)
                .clipped()
            }
        }
        .frame(height: headerHeight)
    }
    
    // MARK: - Day Header Cell
    private func dayHeaderCell(for day: Date, index: Int, width: CGFloat) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        let isSelected = Calendar.current.isDate(day, inSameDayAs: viewModel.selectedDate)
        let apptCount = viewModel.appointments(for: day).count
        let dayNum = Calendar.current.component(.day, from: day)
        let dayName = fullWeekdayName(for: day)
        let closed = isDayClosed(day: day)
        let bg = dayBackgroundColor(for: day, index: index, isToday: isToday, isSelected: isSelected)
        
        return Button {
            Haptics.play(.selection)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                viewModel.selectedDate = day
            }
        } label: {
            ZStack(alignment: .top) {
                bg
                
                // Top accent stripe (red for today, blue for selected)
                if isToday {
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 3)
                } else if isSelected {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(height: 3)
                }
                
                if width < 90 {
                    // Compact centered vertical header for 5-day / 7-day narrow columns
                    VStack(spacing: 2) {
                        Text(dayName.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isToday ? Color.red : (isSelected ? Color.blue : Color.secondary))
                            .lineLimit(1)
                        
                        ZStack {
                            if isToday {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 22, height: 22)
                            } else if isSelected {
                                Circle()
                                    .fill(Color.blue.opacity(0.18))
                                    .frame(width: 22, height: 22)
                            }
                            
                            Text("\(dayNum)")
                                .font(.system(size: 12, weight: isToday || isSelected ? .bold : .semibold))
                                .foregroundStyle(isToday ? Color.white : (isSelected ? Color.blue : Color.primary))
                        }
                        .frame(width: 22, height: 22)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 2)
                } else {
                    HStack(spacing: 6) {
                        // Day Number Circle Badge
                        ZStack {
                            if isToday {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 26, height: 26)
                            } else if isSelected {
                                Circle()
                                    .fill(Color.blue.opacity(0.18))
                                    .frame(width: 26, height: 26)
                            }
                            
                            Text("\(dayNum)")
                                .font(.system(size: 13, weight: isToday || isSelected ? .bold : .semibold))
                                .foregroundStyle(isToday ? Color.white : (isSelected ? Color.blue : Color.primary))
                        }
                        .frame(width: 26, height: 26)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(dayName.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isToday ? Color.red : (isSelected ? Color.blue : Color.primary))
                                .lineLimit(1)
                            
                            if closed && apptCount == 0 {
                                Text("Chiuso")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary)
                            } else if apptCount > 0 {
                                Text("\(apptCount) appt")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(isToday ? Color.red : Color.blue)
                            }
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6)
                    .frame(maxHeight: .infinity)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Time Column (08:00 to 20:00)
    private var timeColumn: some View {
        VStack(spacing: 0) {
            ForEach(minHour..<maxHour, id: \.self) { hour in
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer()
                        Text(String(format: "%02d:00", hour))
                            .font(.system(size: 10, weight: .regular).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .offset(y: -7)
                        Spacer().frame(width: 3)
                    }
                    Spacer()
                }
                .frame(height: hourHeight)
            }
        }
    }
    
    // MARK: - Continuous Multi-Week Day Columns (2gg / 5gg)
    private func continuousDaysContent(colWidth: CGFloat) -> some View {
        let days = timelineDays
        return LazyHStack(alignment: .top, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                HStack(spacing: 0) {
                    dayColumnView(day: day, index: index, width: colWidth)
                        .frame(width: colWidth)
                    verticalSeparator
                }
                .id(day)
            }
        }
    }

    // MARK: - Full Week Pages Content (7gg Paging)
    private func fullWeekPagesContent(colWidth: CGFloat, pageWidth: CGFloat) -> some View {
        LazyHStack(alignment: .top, spacing: 0) {
            ForEach(timelineWeekMondays, id: \.self) { monday in
                let weekDays = daysOfWeek(starting: monday)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(weekDays.enumerated()), id: \.element) { index, day in
                        dayColumnView(day: day, index: index, width: colWidth)
                            .frame(width: colWidth)
                        if index < weekDays.count - 1 {
                            verticalSeparator
                        }
                    }
                }
                .frame(width: pageWidth, alignment: .leading)
                .id(monday)
            }
        }
    }
    
    // MARK: - Single Day Column View
    private func dayColumnView(day: Date, index: Int, width: CGFloat) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        let isSelected = Calendar.current.isDate(day, inSameDayAs: viewModel.selectedDate)
        let dayAppts = viewModel.appointments(for: day)
        let layoutAppts = computeLayout(appointments: dayAppts)
        let closed = isDayClosed(day: day)
        let breakRange = getDayBreak(day: day)
        let bg = dayBackgroundColor(for: day, index: index, isToday: isToday, isSelected: isSelected)
        
        return ZStack(alignment: .topLeading) {
            // Background with alternating contrast
            bg
            
            // 1. Hour Lines & Long-Press-to-Create Slots (scroll-safe)
            VStack(spacing: 0) {
                ForEach(minHour..<maxHour, id: \.self) { hour in
                    ZStack(alignment: .top) {
                        // Full hour divider line
                        Rectangle()
                            .fill(Color.secondary.opacity(0.20))
                            .frame(height: 0.8)
                        
                        // Half-hour divider line
                        Rectangle()
                            .fill(Color.secondary.opacity(0.10))
                            .frame(height: 0.5)
                            .offset(y: hourHeight / 2.0)
                        
                        // Long-press slot (:00)
                        Color.clear
                            .frame(height: hourHeight / 2.0)
                            .contentShape(Rectangle())
                            .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 12) {
                                handleSlotLongPress(day: day, hour: hour, minute: 0)
                            }
                            .offset(y: 0)
                        
                        // Long-press slot (:30)
                        Color.clear
                            .frame(height: hourHeight / 2.0)
                            .contentShape(Rectangle())
                            .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 12) {
                                handleSlotLongPress(day: day, hour: hour, minute: 30)
                            }
                            .offset(y: hourHeight / 2.0)
                    }
                    .frame(height: hourHeight)
                }
            }
            
            // 2. Closed Day watermark
            if closed && dayAppts.isEmpty {
                VStack(spacing: 4) {
                    Spacer().frame(height: 36)
                    Image(systemName: "moon.zzz")
                        .font(.title3)
                        .foregroundStyle(.secondary.opacity(0.35))
                    Text("Salone Chiuso")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary.opacity(0.45))
                }
                .frame(maxWidth: .infinity)
            }
            
            // 3. Lunch break overlay (if configured)
            if let breakRange, let startMin = breakRange.startMin, let endMin = breakRange.endMin, startMin < endMin {
                let breakTop = CGFloat(startMin - minHour * 60) * pixelsPerMinute
                let breakHeight = CGFloat(endMin - startMin) * pixelsPerMinute
                
                if breakTop >= 0 && breakTop < totalGridHeight {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.09))
                        HStack(spacing: 3) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary.opacity(0.7))
                            Text("Pausa")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                        .padding(.leading, 4)
                    }
                    .frame(width: max(0, width - 4), height: max(16, breakHeight))
                    .offset(x: 2, y: breakTop)
                }
            }
            
            // 4. Appointment Cards
            ForEach(layoutAppts) { item in
                let appt = item.appointment
                let topOffset = CGFloat(appt.startMinutes - minHour * 60) * pixelsPerMinute + 1.0
                let duration = max(20, appt.durationMinutes)
                let height = max(26.0, CGFloat(duration) * pixelsPerMinute - 2.0)
                let horizontalInset: CGFloat = width < 70 ? 1.5 : 3.0
                let colGap: CGFloat = 2.0
                let usableWidth = max(20.0, width - horizontalInset * 2.0)
                let cardWidth = max(18.0, (usableWidth - colGap * CGFloat(max(0, item.totalCols - 1))) / CGFloat(max(1, item.totalCols)))
                let leftOffset = horizontalInset + CGFloat(item.colIndex) * (cardWidth + colGap)
                
                WeekAppointmentCard(
                    appointment: appt,
                    width: cardWidth,
                    height: height,
                    isCompact: densityMode == .fullWeek || cardWidth < 88
                )
                    .frame(width: cardWidth, height: height)
                    .offset(x: leftOffset, y: topOffset)
                    .onTapGesture {
                        Haptics.play(.light)
                        selectedAppointment = appt
                    }
                    .contextMenu {
                        Button {
                            selectedAppointment = appt
                        } label: {
                            Label("Visualizza Dettagli", systemImage: "info.circle")
                        }
                        
                        if appt.status == .pending {
                            Button {
                                Task {
                                    if let id = appt.id {
                                        let ok = await viewModel.confirmAppointment(id: id)
                                        if ok { Haptics.play(.success) }
                                    }
                                }
                            } label: {
                                Label("Approva", systemImage: "checkmark.circle")
                            }
                        } else if appt.status == .scheduled {
                            Button {
                                Task {
                                    if let id = appt.id {
                                        let ok = await viewModel.completeAppointment(id: id)
                                        if ok { Haptics.play(.success) }
                                    }
                                }
                            } label: {
                                Label("Completa", systemImage: "checkmark.seal")
                            }
                        }
                        
                        if appt.status != .cancelled {
                            Button {
                                Task {
                                    if let id = appt.id {
                                        let ok = await viewModel.cancelAppointment(id: id)
                                        if ok { Haptics.play(.warning) }
                                    }
                                }
                            } label: {
                                Label("Annulla", systemImage: "xmark.circle")
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            appointmentToDelete = appt
                            showingDeleteAlert = true
                        } label: {
                            Label("Elimina", systemImage: "trash")
                        }
                    }
            }
            
            // 5. Red Current Time Line on Today (Apple Calendar signature)
            if isToday {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    let nowComps = Calendar.current.dateComponents([.hour, .minute], from: timeline.date)
                    let nowMin = (nowComps.hour ?? 0) * 60 + (nowComps.minute ?? 0)
                    let nowOffset = CGFloat(nowMin - minHour * 60) * pixelsPerMinute
                    
                    if nowOffset >= 0 && nowOffset <= totalGridHeight {
                        HStack(spacing: 0) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: -4)
                            Rectangle()
                                .fill(Color.red)
                                .frame(height: 2)
                        }
                        .offset(y: nowOffset - 1)
                        .zIndex(10)
                    }
                }
            }
        }
        .frame(height: totalGridHeight)
    }
    
    // MARK: - Native Scroll Synchronization
    private func syncScrollToSelectedDate(animated: Bool) {
        let targetDay = Self.startOfDay(viewModel.selectedDate)
        let targetMonday = Self.mondayOfWeek(containing: targetDay)
        
        // Recenter 25-week timeline if navigated close to the buffer edge (> 9 weeks away)
        let daysFromAnchor = Calendar.current.dateComponents([.day], from: anchorMonday, to: targetMonday).day ?? 0
        if abs(daysFromAnchor) > (weeksRadius - 3) * 7 {
            anchorMonday = targetMonday
        }
        
        let apply = {
            if miniStripWeekID != targetMonday {
                miniStripWeekID = targetMonday
            }
            if densityMode == .fullWeek {
                if scrolledWeekID != targetMonday {
                    scrolledWeekID = targetMonday
                }
            } else {
                if scrolledDayID != targetDay {
                    scrolledDayID = targetDay
                }
            }
        }
        
        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                apply()
            }
        } else {
            apply()
        }
    }

    private func handleScrolledDayChanged(_ newDay: Date?) {
        guard let newDay, densityMode != .fullWeek else { return }
        let normalizedNew = Self.startOfDay(newDay)
        let newMonday = Self.mondayOfWeek(containing: normalizedNew)
        
        if miniStripWeekID != newMonday {
            withAnimation(.easeInOut(duration: 0.2)) {
                miniStripWeekID = newMonday
            }
        }
        
        let currentSelected = Self.startOfDay(viewModel.selectedDate)
        let lastVisible = Calendar.current.date(byAdding: .day, value: densityMode.visibleDaysCount - 1, to: normalizedNew) ?? normalizedNew
        if currentSelected < normalizedNew || currentSelected > lastVisible {
            lastScrollDrivenDate = normalizedNew
            viewModel.selectedDate = normalizedNew
        }
    }

    private func handleScrolledWeekChanged(_ newMonday: Date?) {
        guard let newMonday, densityMode == .fullWeek else { return }
        let normalizedMonday = Self.startOfDay(newMonday)
        
        if miniStripWeekID != normalizedMonday {
            withAnimation(.easeInOut(duration: 0.2)) {
                miniStripWeekID = normalizedMonday
            }
        }
        
        let currentMonday = Self.mondayOfWeek(containing: viewModel.selectedDate)
        if currentMonday != normalizedMonday {
            let weekdayOffset = Calendar.current.dateComponents([.day], from: currentMonday, to: Self.startOfDay(viewModel.selectedDate)).day ?? 0
            let target = Calendar.current.date(byAdding: .day, value: max(0, min(6, weekdayOffset)), to: normalizedMonday) ?? normalizedMonday
            lastScrollDrivenDate = target
            viewModel.selectedDate = target
        }
    }

    private func handleMiniStripWeekChanged(_ newMonday: Date?) {
        guard let newMonday else { return }
        let normalizedMonday = Self.startOfDay(newMonday)
        let currentMonday = Self.mondayOfWeek(containing: viewModel.selectedDate)
        if currentMonday != normalizedMonday {
            let weekdayOffset = Calendar.current.dateComponents([.day], from: currentMonday, to: Self.startOfDay(viewModel.selectedDate)).day ?? 0
            let target = Calendar.current.date(byAdding: .day, value: max(0, min(6, weekdayOffset)), to: normalizedMonday) ?? normalizedMonday
            viewModel.selectedDate = target
        }
    }
    
    // MARK: - Vertical Separator (Crisp 1.0pt Native Separator)
    private var verticalSeparator: some View {
        Rectangle()
            .fill(separatorColor)
            .frame(width: separatorWidth)
    }

    private var separatorColor: Color {
        #if os(iOS)
        Color(UIColor.opaqueSeparator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }
    
    // MARK: - Actions & Helpers
    
    private func handleSlotLongPress(day: Date, hour: Int, minute: Int) {
        Haptics.play(.medium)
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        let targetDate = cal.date(from: comps) ?? day
        
        onAddAppointment?(targetDate, targetDate)
    }
    
    // Cached formatters to eliminate repeated allocations
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "LLLL yyyy"
        return f
    }()
    
    private static let singleLetterFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEEE"
        return f
    }()
    
    private static let abbreviatedDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEE"
        return f
    }()

    private var monthYearTitle: String {
        Self.monthYearFormatter.string(from: viewModel.selectedDate).capitalized
    }
    
    private func isDayVisibleInTimeline(day: Date) -> Bool {
        if densityMode == .fullWeek {
            return false
        }
        let days = timelineDays
        guard !days.isEmpty else { return false }
        let availableWidth = max(100, timelineWidth - timeColWidth - separatorWidth)
        let colCount = CGFloat(densityMode.visibleDaysCount)
        let colWidth = floor((availableWidth - separatorWidth * (colCount - 1)) / colCount)
        let step = max(1, colWidth + separatorWidth)
        let firstIdx = max(0, min(days.count - 1, Int(round(scrollOffsetX / step))))
        let endIdx = min(days.count - 1, firstIdx + densityMode.visibleDaysCount - 1)
        let target = Self.startOfDay(day)
        return target >= days[firstIdx] && target <= days[endIdx]
    }
    
    /// High-contrast alternating background between adjacent days
    private func dayBackgroundColor(for day: Date, index: Int, isToday: Bool, isSelected: Bool) -> Color {
        if isToday {
            return Color.red.opacity(0.05)
        }
        if isSelected {
            return Color.blue.opacity(0.045)
        }
        // Zebra striping between adjacent days: clearly discernable separation
        return (index % 2 == 1) ? Color.secondary.opacity(0.075) : Color.systemBackgroundCompat
    }
    
    private func shortSingleLetterDay(for date: Date) -> String {
        Self.singleLetterFormatter.string(from: date).uppercased()
    }
    
    private func fullWeekdayName(for date: Date) -> String {
        Self.abbreviatedDayFormatter.string(from: date).capitalized
    }
    
    private func loadBusinessHours() async {
        guard let salonId = salonManager.selectedSalonId else {
            salonBusinessHours = []
            return
        }
        do {
            salonBusinessHours = try await APIClient.shared.getSalonHours(salonId: salonId)
        } catch {
            salonBusinessHours = []
        }
    }
    
    private func isDayClosed(day: Date) -> Bool {
        guard !salonBusinessHours.isEmpty else { return false }
        let jsDay = Calendar.current.component(.weekday, from: day) // 1=Sun, 2=Mon...
        let dayOfWeek = (jsDay == 1) ? 0 : (jsDay - 1)
        if let hour = salonBusinessHours.first(where: { $0.dayOfWeek == dayOfWeek }) {
            return !hour.isOpen
        }
        return false
    }
    
    private func getDayBreak(day: Date) -> (startMin: Int?, endMin: Int?)? {
        guard !salonBusinessHours.isEmpty else { return nil }
        let jsDay = Calendar.current.component(.weekday, from: day)
        let dayOfWeek = (jsDay == 1) ? 0 : (jsDay - 1)
        if let hour = salonBusinessHours.first(where: { $0.dayOfWeek == dayOfWeek }),
           let bStart = hour.breakStart, let bEnd = hour.breakEnd,
           !bStart.isEmpty, !bEnd.isEmpty {
            let sParts = bStart.split(separator: ":").compactMap { Int($0) }
            let eParts = bEnd.split(separator: ":").compactMap { Int($0) }
            if sParts.count >= 2 && eParts.count >= 2 {
                return (sParts[0] * 60 + sParts[1], eParts[0] * 60 + eParts[1])
            }
        }
        return nil
    }
    
    // MARK: - Overlap Layout Algorithm
    private func computeLayout(appointments: [Appointment]) -> [LayoutAppointment] {
        let valid = appointments.filter { $0.status != .cancelled }
        guard !valid.isEmpty else { return [] }
        
        let sorted = valid.sorted {
            if $0.startMinutes != $1.startMinutes {
                return $0.startMinutes < $1.startMinutes
            }
            return $0.durationMinutes > $1.durationMinutes
        }
        
        var clusters: [[Appointment]] = []
        var currentCluster: [Appointment] = []
        var clusterEndMinutes = 0
        
        for appt in sorted {
            if currentCluster.isEmpty {
                currentCluster.append(appt)
                clusterEndMinutes = appt.endMinutes
            } else if appt.startMinutes < clusterEndMinutes {
                currentCluster.append(appt)
                clusterEndMinutes = max(clusterEndMinutes, appt.endMinutes)
            } else {
                clusters.append(currentCluster)
                currentCluster = [appt]
                clusterEndMinutes = appt.endMinutes
            }
        }
        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }
        
        var result: [LayoutAppointment] = []
        for cluster in clusters {
            var columns: [[Appointment]] = []
            for appt in cluster {
                var placed = false
                for (idx, col) in columns.enumerated() {
                    if let last = col.last, last.endMinutes <= appt.startMinutes {
                        columns[idx].append(appt)
                        placed = true
                        break
                    }
                }
                if !placed {
                    columns.append([appt])
                }
            }
            
            let totalCols = columns.count
            for (colIdx, col) in columns.enumerated() {
                for appt in col {
                    result.append(LayoutAppointment(appointment: appt, colIndex: colIdx, totalCols: totalCols))
                }
            }
        }
        return result
    }
}

// MARK: - Layout Appointment Model
struct LayoutAppointment: Identifiable {
    var id: UUID { appointment.id ?? UUID() }
    let appointment: Appointment
    let colIndex: Int
    let totalCols: Int
}

// MARK: - Week Appointment Card View
struct WeekAppointmentCard: View {
    let appointment: Appointment
    let width: CGFloat
    let height: CGFloat
    let isCompact: Bool

    private var accentColor: Color {
        if let staffColor = appointment.staffMember?.color, !staffColor.isEmpty {
            return Color(hex: staffColor)
        }
        return semanticStatusColor
    }

    private var semanticStatusColor: Color {
        switch appointment.status {
        case .scheduled: return .blue
        case .pending: return .orange
        case .completed: return .green
        case .rescheduled: return .purple
        case .cancelled: return .red
        case .expired: return .gray
        case .none: return .blue
        }
    }

    private var isPending: Bool {
        appointment.status == .pending
    }

    private var isCompleted: Bool {
        appointment.status == .completed
    }

    private var clientDisplayName: String {
        guard let client = appointment.client else { return "Cliente" }
        if width < 64 {
            return client.firstName.isEmpty ? client.fullName : client.firstName
        }
        return client.fullName
    }

    private var timeLabel: String {
        if isCompact || width < 110 {
            return appointment.startTime
        }
        return appointment.timeRange
    }

    private var servicesSummary: String? {
        guard let services = appointment.services, let first = services.first else { return nil }
        return services.count > 1 ? "\(first.name) +\(services.count - 1)" : first.name
    }

    private var hasAllergies: Bool {
        if let allergies = appointment.client?.allergies, !allergies.isEmpty {
            return true
        }
        return false
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left solid accent stripe
            Rectangle()
                .fill(accentColor)
                .frame(width: width < 64 ? 3 : 3.5)

            Group {
                if height < 36 {
                    // Ultra-compact single-line layout for short (<= 30 min) slots
                    HStack(spacing: 4) {
                        Text(appointment.startTime)
                            .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                            .foregroundStyle(accentColor)
                            .lineLimit(1)
                            .fixedSize()

                        if width >= 72 {
                            Text(clientDisplayName)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        if width >= 85, let status = appointment.status {
                            Image(systemName: status.iconName)
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundStyle(semanticStatusColor)
                        }
                    }
                    .padding(.horizontal, width < 64 ? 3 : 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        // Top row: time + status indicator (+ allergy warning)
                        HStack(spacing: 3) {
                            Text(timeLabel)
                                .font(.system(size: width < 64 ? 9 : 10, weight: .bold).monospacedDigit())
                                .foregroundStyle(accentColor)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            if hasAllergies && width >= 82 {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.red)
                            }

                            if width >= 62, let status = appointment.status {
                                Image(systemName: status.iconName)
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundStyle(semanticStatusColor)
                            }
                        }

                        // Client Name
                        Text(clientDisplayName)
                            .font(.system(size: width < 64 ? 10 : 11.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(height >= 72 && width < 80 ? 2 : 1)

                        // Service summary (if height permits)
                        if height >= 52, width >= 68, let summary = servicesSummary {
                            Text(summary)
                                .font(.system(size: 9.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        // Bottom footer: Staff + Price (if tall & wide enough)
                        if height >= 72, width >= 92 {
                            Spacer(minLength: 0)
                            HStack(spacing: 4) {
                                if let staff = appointment.staffMember {
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(Color(hex: staff.color ?? "#9333EA"))
                                            .frame(width: 5, height: 5)
                                        Text(staff.displayName)
                                            .font(.system(size: 8.5, weight: .medium))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer(minLength: 2)

                                if appointment.totalPrice != nil || appointment.finalPrice != nil {
                                    Text(appointment.formattedFinalPrice)
                                        .font(.system(size: 9, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(.primary.opacity(0.8))
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                            }
                        } else {
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.horizontal, width < 64 ? 3 : 6)
                    .padding(.vertical, 4)
                }
            }
        }
        .background(
            ZStack {
                Color.systemBackgroundCompat
                accentColor.opacity(isCompleted ? 0.10 : 0.15)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(
                    isPending ? Color.orange.opacity(0.75) : accentColor.opacity(0.32),
                    style: isPending
                        ? StrokeStyle(lineWidth: 1.1, dash: [4, 2.5])
                        : StrokeStyle(lineWidth: 0.75)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 1.5, x: 0, y: 1)
        .opacity(isCompleted ? 0.82 : 1.0)
        .contentShape(Rectangle())
    }
}
