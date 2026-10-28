import SwiftUI
import Combine

enum WeekDensityMode: String, CaseIterable, Identifiable {
    case twoDays = "2gg"
    case fullWeek = "Settimana"
    var id: String { rawValue }
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
    
    private let hourHeight: CGFloat = 64.0
    private let timeColWidth: CGFloat = 44.0
    private let headerHeight: CGFloat = 46.0
    private let separatorWidth: CGFloat = 1.0
    
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
            
            // MARK: - 2. Apple Calendar 7-Day Mini Strip (Lun..Dom)
            weekDaysMiniStrip
                .background(Color.systemBackgroundCompat)
                .zIndex(9)
            
            Divider()
            
            // MARK: - 3. Time Grid Area
            if viewModel.isLoading && viewModel.appointments.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Caricamento appuntamenti...")
                    Spacer()
                }
            } else {
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let availableWidth = max(100, totalWidth - timeColWidth - separatorWidth)
                    
                    let colCount: CGFloat = (densityMode == .twoDays) ? 2.0 : 7.0
                    let colWidth = floor((availableWidth - separatorWidth * (colCount - 1)) / colCount)
                    
                    VStack(spacing: 0) {
                        // MARK: - Sticky Day Headers Strip (Synchronized with columns below!)
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
                                
                                // Horizontal Scrollable Day Columns
                                if densityMode == .fullWeek {
                                    // In full week mode: all 7 days fit screen without horizontal scroll
                                    daysColumnsContent(colWidth: colWidth)
                                        .frame(width: availableWidth)
                                } else {
                                    // In 2gg mode: smooth horizontal scroll with snapping between days!
                                    ScrollViewReader { horizontalProxy in
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            daysColumnsContent(colWidth: colWidth)
                                                .scrollTargetLayout()
                                        }
                                        .scrollTargetBehavior(.viewAligned)
                                        .frame(width: availableWidth)
                                        .onScrollGeometryChange(for: CGFloat.self) { geo in
                                            geo.contentOffset.x
                                        } action: { _, newOffset in
                                            scrollOffsetX = newOffset
                                        }
                                        .onAppear {
                                            scrollToSelectedDay(proxy: horizontalProxy)
                                        }
                                        .onChange(of: viewModel.selectedDate) {
                                            scrollToSelectedDay(proxy: horizontalProxy)
                                        }
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
        .task(id: salonManager.selectedSalonId) {
            await loadBusinessHours()
        }
        .onChange(of: densityMode) { _, newMode in
            if newMode == .fullWeek {
                scrollOffsetX = 0
            }
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
            
            // View Density Selector (2gg | Settimana)
            Picker("Vista", selection: $densityMode) {
                ForEach(WeekDensityMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 135)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - 2. Apple Calendar 7-Day Mini Strip (L M M G V S D)
    private var weekDaysMiniStrip: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: timeColWidth + separatorWidth)
            
            HStack(spacing: 0) {
                ForEach(Array(viewModel.currentWeekDays.enumerated()), id: \.element) { index, day in
                    let isToday = Calendar.current.isDateInToday(day)
                    let isSelected = Calendar.current.isDate(day, inSameDayAs: viewModel.selectedDate)
                    let isVisible = isDayVisibleInTimeline(index: index)
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
            .padding(.trailing, 6)
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
            
            // Day Headers HStack (offset smoothly by -scrollOffsetX in scrollable modes!)
            HStack(spacing: 0) {
                ForEach(Array(viewModel.currentWeekDays.enumerated()), id: \.element) { index, day in
                    dayHeaderCell(for: day, index: index, width: colWidth)
                        .frame(width: colWidth, height: headerHeight)
                    
                    // Separator after each header cell
                    verticalSeparator
                }
            }
            .offset(x: (densityMode == .fullWeek) ? 0 : -scrollOffsetX)
            .frame(width: availableWidth, alignment: .leading)
            .clipped()
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
    
    // MARK: - Days Columns Content HStack
    private func daysColumnsContent(colWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(viewModel.currentWeekDays.enumerated()), id: \.element) { index, day in
                dayColumnView(day: day, index: index, width: colWidth)
                    .frame(width: colWidth)
                    .id(Calendar.current.startOfDay(for: day))
                
                // Vertical Separator after each column
                verticalSeparator
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
            
            // 1. Hour Lines & Tappable Add Slots
            VStack(spacing: 0) {
                ForEach(minHour..<maxHour, id: \.self) { hour in
                    ZStack(alignment: .top) {
                        // Full hour divider line
                        Rectangle()
                            .fill(Color.secondary.opacity(0.20))
                            .frame(height: 0.8)
                        
                        // Half-hour dashed divider line
                        Rectangle()
                            .fill(Color.secondary.opacity(0.10))
                            .frame(height: 0.5)
                            .offset(y: hourHeight / 2.0)
                        
                        // Tappable slot to add appointment (:00)
                        Button {
                            handleSlotTap(day: day, hour: hour, minute: 0)
                        } label: {
                            Color.clear
                                .frame(height: hourHeight / 2.0)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .offset(y: 0)
                        
                        // Tappable slot to add appointment (:30)
                        Button {
                            handleSlotTap(day: day, hour: hour, minute: 30)
                        } label: {
                            Color.clear
                                .frame(height: hourHeight / 2.0)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
                let topOffset = CGFloat(appt.startMinutes - minHour * 60) * pixelsPerMinute
                let duration = max(20, appt.durationMinutes)
                let height = max(26.0, CGFloat(duration) * pixelsPerMinute - 2.0)
                let cardWidth = max(20.0, (width - 4.0) / CGFloat(item.totalCols) - 2.0)
                let leftOffset = 2.0 + CGFloat(item.colIndex) * ((width - 4.0) / CGFloat(item.totalCols))
                
                WeekAppointmentCard(appointment: appt, width: cardWidth, height: height, isCompact: densityMode == .fullWeek)
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
    
    // MARK: - Vertical Separator (Crisp 1.0pt Native Separator)
    private var verticalSeparator: some View {
        Rectangle()
            .fill(Color(UIColor.opaqueSeparator))
            .frame(width: separatorWidth)
    }
    
    // MARK: - Actions & Helpers
    
    private func handleSlotTap(day: Date, hour: Int, minute: Int) {
        Haptics.play(.selection)
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        let targetDate = cal.date(from: comps) ?? day
        
        onAddAppointment?(targetDate, targetDate)
    }
    
    private func scrollToSelectedDay(proxy: ScrollViewProxy) {
        let startOfDay = Calendar.current.startOfDay(for: viewModel.selectedDate)
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(startOfDay, anchor: .leading)
        }
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
        Self.monthYearFormatter.string(from: viewModel.currentWeekMonday).capitalized
    }
    
    private func isDayVisibleInTimeline(index: Int) -> Bool {
        if densityMode == .fullWeek {
            return true
        }
        let availableWidth = max(100, timelineWidth - timeColWidth - separatorWidth)
        let colWidth = floor((availableWidth - separatorWidth) / 2.0)
        let step = colWidth + separatorWidth
        guard step > 0 else { return index < 2 }
        let firstIndex = max(0, min(5, Int(round(scrollOffsetX / step))))
        return index >= firstIndex && index < firstIndex + 2
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
    
    private var statusColor: Color {
        if let staffColor = appointment.staffMember?.color, !staffColor.isEmpty {
            return Color(hex: staffColor)
        }
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
    
    var body: some View {
        HStack(spacing: 0) {
            // Left solid accent stripe
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor)
                .frame(width: 3.5)
            
            VStack(alignment: .leading, spacing: 2) {
                // Time Range & Status Icon
                HStack(spacing: 3) {
                    Text(appointment.timeRange)
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                    
                    if let status = appointment.status {
                        Image(systemName: status.iconName)
                            .font(.system(size: 8))
                            .foregroundStyle(statusColor)
                    }
                }
                
                // Client Name
                if let client = appointment.client {
                    Text(client.fullName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else {
                    Text("Cliente")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                }
                
                // Service Name (if card height permits)
                if height >= 40, let services = appointment.services, let first = services.first {
                    Text(first.name + (services.count > 1 ? " (+\(services.count - 1))" : ""))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                // Staff member pill (if card height permits)
                if height >= 58, let staff = appointment.staffMember {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color(hex: staff.color ?? "#9333EA"))
                            .frame(width: 5, height: 5)
                        Text(staff.displayName)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(statusColor.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(statusColor.opacity(0.35), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
}
