import SwiftUI
import EventKit
import Combine

public struct CalendarCleanerView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        ZStack {
            AppTheme.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.authStatus == .denied || viewModel.authStatus == .restricted {
                    deniedView
                } else if viewModel.isLoading && viewModel.allEvents.isEmpty {
                    loadingView
                } else if viewModel.authStatus == .notDetermined {
                    permissionPromptView
                } else if viewModel.allEvents.isEmpty {
                    emptyStateView
                } else {
                    eventListView
                }
            }
            
            if !viewModel.selectedIds.isEmpty {
                bottomBar
            }
        }
        .navigationTitle("Calendar Cleanup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    HapticManager.selection()
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.appleBlue)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    Button(action: {
                        HapticManager.impact(style: .light)
                        Task {
                            await viewModel.loadEvents()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.cyan)
                    }

                    if !viewModel.selectedIds.isEmpty {
                        Button(action: {
                            HapticManager.impact(style: .heavy)
                            viewModel.deleteSelected()
                        }) {
                            Text("Delete (\(viewModel.selectedIds.count))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .task {
            if viewModel.hasAccess {
                await viewModel.loadEvents()
            }
        }
        .onAppear {
            if viewModel.hasAccess {
                Task {
                    await viewModel.loadEvents()
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active && viewModel.hasAccess {
                Task {
                    await viewModel.loadEvents()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            Task {
                await viewModel.loadEvents()
            }
        }
    }

    // MARK: - Subviews

    private var permissionPromptView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 54))
                .foregroundColor(.green)
            VStack(spacing: 8) {
                Text("Calendar Access")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.white)
                Text("Allow access to scan, manage, and clean calendar events")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: {
                Task { await viewModel.requestAccess() }
            }) {
                Text("Allow Calendar Access")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.green))
            }
            .buttonStyle(ScaleButtonStyle())
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var deniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.yellow)
            Text("Calendar Access Denied")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.white)
            Text("Enable Calendar access in iOS Settings to scan and clean events.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.cyan)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(.green)
                .scaleEffect(1.4)
            Text("Scanning calendar events...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54))
                .foregroundColor(.green)
            Text("Calendar is Clean!")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.white)
            Text("No modifiable personal calendar events found.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Text("Public holidays and subscribed calendars are protected.")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)

            Button(action: {
                HapticManager.impact(style: .light)
                Task {
                    await viewModel.loadEvents()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Calendar")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.green.opacity(0.15)))
            }
            .padding(.top, 10)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var eventListView: some View {
        VStack(spacing: 0) {
            // Filter Pills Header
            filterPillsBar

            // Sub-bar with selection counter & Select All
            HStack {
                Text("\(viewModel.filteredEvents.count) \(viewModel.selectedFilter.rawValue.lowercased()) events")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                
                Spacer()
                
                if !viewModel.filteredEvents.isEmpty {
                    Button(viewModel.isAllFilteredSelected ? "Deselect All" : "Select All") {
                        HapticManager.selection()
                        viewModel.toggleSelectAllFiltered()
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "30D158"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.02))

            if viewModel.filteredEvents.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.textMuted)
                    Text("No \(viewModel.selectedFilter.rawValue.lowercased()) events found")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Try switching filter or add events in Calendar.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredEvents) { event in
                            eventRow(event)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 96)
                }
                .refreshable {
                    await viewModel.loadEvents()
                }
            }
        }
    }

    private var filterPillsBar: some View {
        HStack(spacing: 8) {
            ForEach(CalendarViewModel.Filter.allCases) { filter in
                let isSelected = viewModel.selectedFilter == filter
                let count = viewModel.count(for: filter)

                Button(action: {
                    HapticManager.selection()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.selectedFilter = filter
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(filter.rawValue)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        
                        Text("\(count)")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                            )
                    }
                    .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.green : Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var bottomBar: some View {
        VStack {
            Spacer()
            GlassCard(cornerRadius: 24) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.selectedIds.count) marked")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text("Remove from Calendar")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        HapticManager.impact(style: .heavy)
                        viewModel.deleteSelected()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Clean Events")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color(hex: "FF3B30")))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private func eventRow(_ event: CalendarEventItem) -> some View {
        Button(action: {
            HapticManager.selection()
            viewModel.toggleSelection(event.id)
        }) {
            GlassCard(cornerRadius: 12) {
                HStack(spacing: 12) {
                    // Calendar colour indicator
                    Circle()
                        .fill(event.calendarColor)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(event.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            statusBadge(for: event)
                        }

                        HStack(spacing: 6) {
                            Text(event.calendarName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textMuted)
                            Text("•")
                                .foregroundColor(AppTheme.textMuted)
                            Text(event.formattedDateString)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: viewModel.selectedIds.contains(event.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(viewModel.selectedIds.contains(event.id) ? Color(hex: "30D158") : Color.white.opacity(0.3))
                }
                .padding(12)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func statusBadge(for event: CalendarEventItem) -> some View {
        if event.isToday {
            Text("TODAY")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color(hex: "30D158")))
        } else if event.isPast {
            Text("PAST")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        } else {
            Text("UPCOMING")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.cyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.cyan.opacity(0.15)))
        }
    }
}

// MARK: - ViewModel

@MainActor
private class CalendarViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case past = "Past"
        case upcoming = "Upcoming"
        var id: String { rawValue }
    }

    @Published var allEvents: [CalendarEventItem] = []
    @Published var selectedFilter: Filter = .all
    @Published var selectedIds: Set<String> = []
    @Published var isLoading = false
    @Published var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private let store = EKEventStore()

    var filteredEvents: [CalendarEventItem] {
        switch selectedFilter {
        case .all:
            return allEvents
        case .past:
            return allEvents.filter { $0.isPast }
        case .upcoming:
            return allEvents.filter { !$0.isPast }
        }
    }

    var isAllFilteredSelected: Bool {
        let currentFiltered = filteredEvents
        guard !currentFiltered.isEmpty else { return false }
        return currentFiltered.allSatisfy { selectedIds.contains($0.id) }
    }

    func count(for filter: Filter) -> Int {
        switch filter {
        case .all:
            return allEvents.count
        case .past:
            return allEvents.filter { $0.isPast }.count
        case .upcoming:
            return allEvents.filter { !$0.isPast }.count
        }
    }

    // True if we have sufficient access to read events
    var hasAccess: Bool {
        if #available(iOS 17.0, *) {
            return authStatus == .fullAccess
        } else {
            return authStatus == .authorized
        }
    }

    func requestAccess() async {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await store.requestFullAccessToEvents()
                authStatus = granted ? .fullAccess : .denied
            } else {
                let granted = try await store.requestAccess(to: .event)
                authStatus = granted ? .authorized : .denied
            }
            if hasAccess {
                await loadEvents()
            }
        } catch {
            authStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }

    func loadEvents() async {
        isLoading = true

        // Reset store and refresh sources to guarantee freshly synced and newly added events are visible
        store.reset()
        store.refreshSourcesIfNecessary()

        let now = Date()
        // Broad range: 3 years in the past to 2 years in the future
        let threeYearsAgo = Calendar.current.date(byAdding: .year, value: -3, to: now) ?? now
        let twoYearsAhead = Calendar.current.date(byAdding: .year, value: 2, to: now) ?? now

        // Get personal modifiable calendars
        let allCalendars = store.calendars(for: .event)
        let personalModifiableCalendars = allCalendars.filter { cal in
            // 1. Must allow content modifications
            guard cal.allowsContentModifications else { return false }
            
            // 2. Exclude subscribed and birthday calendar types
            guard cal.type != .subscription && cal.type != .birthday else { return false }
            
            // 3. Exclude subscribed and birthday source types
            if cal.source.sourceType == .subscribed || cal.source.sourceType == .birthdays {
                return false
            }
            
            return true
        }

        guard !personalModifiableCalendars.isEmpty else {
            self.allEvents = []
            self.selectedIds = []
            self.isLoading = false
            return
        }

        let predicate = store.predicateForEvents(withStart: threeYearsAgo, end: twoYearsAhead, calendars: personalModifiableCalendars)
        let ekEvents = store.events(matching: predicate)

        // Strict verification: only personal events the user can modify
        let validEvents = ekEvents.filter { ek in
            guard let cal = ek.calendar else { return false }
            guard cal.allowsContentModifications else { return false }
            guard cal.type != .subscription && cal.type != .birthday else { return false }
            return true
        }

        // Sort: Past events newest first, Upcoming events nearest first
        self.allEvents = validEvents
            .map { CalendarEventItem(ekEvent: $0) }
            .sorted { (a, b) -> Bool in
                // If both are past, show newest first
                if a.isPast && b.isPast {
                    return a.startDate > b.startDate
                }
                // If both upcoming, show nearest first
                if !a.isPast && !b.isPast {
                    return a.startDate < b.startDate
                }
                // Upcoming comes before past in the general list or vice versa
                return a.startDate < b.startDate
            }

        // Filter out any stale selectedIds that no longer exist
        let existingIds = Set(self.allEvents.map { $0.id })
        self.selectedIds = self.selectedIds.intersection(existingIds)

        isLoading = false
    }

    func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    func toggleSelectAllFiltered() {
        let currentFilteredIds = filteredEvents.map { $0.id }
        if isAllFilteredSelected {
            for id in currentFilteredIds {
                selectedIds.remove(id)
            }
        } else {
            for id in currentFilteredIds {
                selectedIds.insert(id)
            }
        }
    }

    func deleteSelected() {
        let toDelete = allEvents.filter { selectedIds.contains($0.id) }
        var deletedIds: Set<String> = []
        
        for item in toDelete {
            if let ek = store.event(withIdentifier: item.ekIdentifier) {
                // Double check before deleting: only user-modifiable events
                if let cal = ek.calendar, cal.allowsContentModifications && cal.type != .subscription {
                    do {
                        // First try removing this specific event occurrence
                        try store.remove(ek, span: .thisEvent, commit: true)
                        deletedIds.insert(item.id)
                    } catch {
                        do {
                            // If recurring requires future events span
                            try store.remove(ek, span: .futureEvents, commit: true)
                            deletedIds.insert(item.id)
                        } catch {
                            print("Error deleting calendar event: \(item.title) error: \(error)")
                        }
                    }
                }
            } else {
                // If it no longer exists in store, mark as deleted from UI
                deletedIds.insert(item.id)
            }
        }
        
        withAnimation(.easeInOut) {
            allEvents.removeAll { deletedIds.contains($0.id) }
            selectedIds.subtract(deletedIds)
        }
        
        if !deletedIds.isEmpty {
            HapticManager.notification(type: .success)
        } else {
            HapticManager.notification(type: .error)
        }
    }
}

// MARK: - Data Model

struct CalendarEventItem: Identifiable, Equatable {
    let id: String
    let ekIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarName: String
    let calendarColor: Color

    init(ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.ekIdentifier = ekEvent.eventIdentifier ?? ""
        self.title = (ekEvent.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Event" : (ekEvent.title ?? "Untitled Event")
        self.startDate = ekEvent.startDate ?? Date()
        self.endDate = ekEvent.endDate ?? self.startDate
        self.isAllDay = ekEvent.isAllDay
        self.calendarName = ekEvent.calendar?.title ?? "Calendar"
        let cgColor = ekEvent.calendar?.cgColor
        self.calendarColor = cgColor.map { Color(cgColor: $0) } ?? .green
    }

    var isPast: Bool {
        endDate < Date()
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(startDate)
    }

    var formattedDateString: String {
        let cal = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        if isAllDay {
            if cal.isDateInToday(startDate) {
                return "Today • All Day"
            } else if cal.isDateInTomorrow(startDate) {
                return "Tomorrow • All Day"
            } else if cal.isDateInYesterday(startDate) {
                return "Yesterday • All Day"
            } else {
                let df = DateFormatter()
                df.dateStyle = .medium
                return "\(df.string(from: startDate)) • All Day"
            }
        } else {
            let timeStr = timeFormatter.string(from: startDate)
            if cal.isDateInToday(startDate) {
                return "Today at \(timeStr)"
            } else if cal.isDateInTomorrow(startDate) {
                return "Tomorrow at \(timeStr)"
            } else if cal.isDateInYesterday(startDate) {
                return "Yesterday at \(timeStr)"
            } else {
                let df = DateFormatter()
                df.dateStyle = .medium
                return "\(df.string(from: startDate)) • \(timeStr)"
            }
        }
    }
}
