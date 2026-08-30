import SwiftUI
import SwiftData

public enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case available = "Available"
    case courses = "Courses"
    case singles = "Singles"
    case sos = "SOS"
    case sleep = "Sleep"
    case work = "Work"
    case sport = "Sport"
    
    public var id: String { rawValue }
}

public enum DurationFilter: String, CaseIterable, Identifiable {
    case all = "Any Duration"
    case short = "< 5 min"
    case medium = "5-10 min"
    case standard = "10-20 min"
    case long = "20+ min"
    
    public var id: String { rawValue }
    
    public func matches(seconds: Double) -> Bool {
        let mins = seconds / 60.0
        switch self {
        case .all: return true
        case .short: return mins < 5.0
        case .medium: return mins >= 5.0 && mins <= 10.0
        case .standard: return mins > 10.0 && mins <= 20.0
        case .long: return mins > 20.0
        }
    }
}

public enum MediaFilter: String, CaseIterable, Identifiable {
    case all = "All Media"
    case audio = "Audio"
    case video = "Video"
    
    public var id: String { rawValue }
}

public enum StatusFilter: String, CaseIterable, Identifiable {
    case all = "All Sessions"
    case unplayed = "Unplayed"
    case completed = "Completed"
    case favorites = "Favorites"
    
    public var id: String { rawValue }
}

/// Searchable course and singles library with explicit availability states.
public struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var catalogService = CatalogService.shared
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    
    @Query(sort: \CompletionEvent.timestamp, order: .reverse) private var completionEvents: [CompletionEvent]
    @Query private var favorites: [FavoriteItem]
    
    @State private var searchText = ""
    @State private var selectedFilter: LibraryFilter = .all
    @State private var selectedDuration: DurationFilter = .all
    @State private var selectedMedia: MediaFilter = .all
    @State private var selectedStatus: StatusFilter = .all
    @State private var showFilterSheet: Bool = false
    
    public init() {}
    
    private var completedIDs: Set<String> {
        Set(completionEvents.filter { $0.isQualifyingMeditation }.map { $0.sessionStableId })
    }
    
    private var favoriteIDs: Set<String> {
        Set(favorites.map { $0.sessionStableId })
    }
    
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var hasActiveSecondaryFilters: Bool {
        selectedDuration != .all || selectedMedia != .all || selectedStatus != .all
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MindSpaceTheme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // MARK: - Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Library")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(MindSpaceTheme.textPrimary)
                            
                            Text("Courses, singles, SOS, sleep, and focus")
                                .font(.subheadline)
                                .foregroundColor(MindSpaceTheme.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // MARK: - Search Bar & Filter Button
                        HStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(MindSpaceTheme.textSecondary)
                                
                                TextField("Search courses, singles, topics...", text: $searchText)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(MindSpaceTheme.textPrimary)
                                    .autocorrectionDisabled()
                                    .accessibilityIdentifier("library.search")
                                
                                if isSearching {
                                    Button(action: {
                                        HapticService.shared.light()
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(MindSpaceTheme.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .accessibilityLabel("Clear search")
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(MindSpaceTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(isSearching ? MindSpaceTheme.accent.opacity(0.6) : MindSpaceTheme.divider, lineWidth: 1)
                            )
                            
                            // Secondary Filters Button
                            Button(action: {
                                HapticService.shared.light()
                                showFilterSheet.toggle()
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(hasActiveSecondaryFilters ? MindSpaceTheme.accent : MindSpaceTheme.surface)
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(MindSpaceTheme.divider, lineWidth: 1)
                                        )
                                    
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(hasActiveSecondaryFilters ? .white : MindSpaceTheme.textPrimary)
                                }
                            }
                            .buttonStyle(.mindSpacePressable)
                            .accessibilityLabel(hasActiveSecondaryFilters ? "Filters, active" : "Filters")
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Filter Chips (Courses, Singles, SOS, Sleep, Work, Sport)
                        if !isSearching {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(LibraryFilter.allCases) { filter in
                                        FilterChip(
                                            filter.rawValue,
                                            isSelected: selectedFilter == filter
                                        ) {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedFilter = filter
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // MARK: - Active Filter Badges (if any)
                        if hasActiveSecondaryFilters && !isSearching {
                            activeFiltersBar
                        }
                        
                        // MARK: - Content
                        if isSearching {
                            searchResultsView
                        } else {
                            categoryHierarchyView
                        }
                        
                        Spacer(minLength: 90)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showFilterSheet) {
                secondaryFiltersSheet
            }
        }
    }
    
    // MARK: - Active Filters Bar
    private var activeFiltersBar: some View {
        HStack(spacing: 8) {
            Text("Filters")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(MindSpaceTheme.textSecondary)
            
            if selectedDuration != .all {
                filterPill(selectedDuration.rawValue) { selectedDuration = .all }
            }
            if selectedMedia != .all {
                filterPill(selectedMedia.rawValue) { selectedMedia = .all }
            }
            if selectedStatus != .all {
                filterPill(selectedStatus.rawValue) { selectedStatus = .all }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    private func filterPill(_ title: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(MindSpaceTheme.warning)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(MindSpaceTheme.warning)
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Remove \(title) filter")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(MindSpaceTheme.accent.opacity(0.3))
        .clipShape(Capsule())
    }
    
    // MARK: - Category Hierarchy (8 Packs & 15 Singles)
    @ViewBuilder
    private var categoryHierarchyView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // PACKS / COURSES SECTION
            if selectedFilter == .all || selectedFilter == .available || selectedFilter == .courses || selectedFilter == .work || selectedFilter == .sport {
                if let categories = catalogService.manifest?.categories {
                    let filteredCategories = categories.filter { cat in
                        if selectedFilter == .work { return cat.name.localizedCaseInsensitiveContains("work") }
                        if selectedFilter == .sport { return cat.name.localizedCaseInsensitiveContains("sport") }
                        return true
                    }
                    
                    let categoriesWithMatches = filteredCategories.filter { cat in
                        cat.courses.contains { matchesFilters(course: $0) }
                    }
                    
                    if !categoriesWithMatches.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Courses")
                                .font(.title3.bold())
                                .foregroundColor(MindSpaceTheme.textPrimary)
                                .padding(.horizontal, 20)
                            
                            ForEach(categoriesWithMatches) { category in
                                let matchingCourses = category.courses.filter { matchesFilters(course: $0) }
                                if !matchingCourses.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(category.name)
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(MindSpaceTheme.secondaryAccent)
                                            Spacer()
                                            Text("\(matchingCourses.count) courses")
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(MindSpaceTheme.textSecondary)
                                        }
                                        .padding(.horizontal, 20)
                                        
                                        ForEach(matchingCourses) { course in
                                            NavigationLink(destination: CourseDetailView(course: course)) {
                                                courseRow(course: course, category: category)
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.horizontal, 20)
                                            .accessibilityIdentifier("library.course.\(course.id)")
                                        }
                                    }
                                    .padding(.bottom, 6)
                                }
                            }
                        }
                    }
                }
            }
            
            // SINGLES SECTION
            if selectedFilter == .all || selectedFilter == .available || selectedFilter == .singles || selectedFilter == .sos || selectedFilter == .sleep || selectedFilter == .work || selectedFilter == .sport {
                if let singlesCats = catalogService.manifest?.singlesCategories {
                    let filteredSingles = singlesCats.filter { cat in
                        if selectedFilter == .sos { return cat.name == "SOS" || cat.name.contains("Anxious") }
                        if selectedFilter == .sleep { return cat.name.contains("Sleep") || cat.name.contains("Good Night") || cat.name.contains("Unwind") }
                        if selectedFilter == .work { return cat.name.localizedCaseInsensitiveContains("work") || cat.name.localizedCaseInsensitiveContains("focus") }
                        if selectedFilter == .sport { return cat.name.localizedCaseInsensitiveContains("sport") }
                        return true
                    }
                    
                    let categoriesWithMatches = filteredSingles.filter { cat in
                        cat.sessions.contains { matchesFilters(session: $0) }
                    }
                    
                    if !categoriesWithMatches.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Singles")
                                .font(.title3.bold())
                                .foregroundColor(MindSpaceTheme.textPrimary)
                                .padding(.horizontal, 20)
                            
                            ForEach(categoriesWithMatches) { cat in
                                let matchingSessions = cat.sessions.filter { matchesFilters(session: $0) }
                                if !matchingSessions.isEmpty {
                                    NavigationLink(destination: SinglesListView(category: cat, onSelectSession: { single in
                                        HapticService.shared.medium()
                                        let track = PlayableTrack(
                                            id: single.id,
                                            title: single.title,
                                            courseName: cat.name,
                                            relativePath: single.relativePath,
                                            duration: single.duration,
                                            contentType: cat.name.lowercased().contains("sleep") ? "sleep" : "meditation"
                                        )
                                        playbackEngine.loadAndPlay(track: track)
                                        playbackEngine.isFullPlayerPresented = true
                                    })) {
                                        singlesCategoryRow(category: cat, count: matchingSessions.count)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 20)
                                    .accessibilityIdentifier("library.singles.\(cat.id)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func courseRow(course: CatalogCourse, category: CatalogCategory) -> some View {
        let isAvailable = course.sessions.allSatisfy { LibraryPathResolver.shared.isFileAvailable(relativePath: $0.relativePath) }
        
        return MindSpaceCard(padding: 14) {
            HStack(spacing: 14) {
                MindSpaceCourseBadge(name: category.name, size: 44)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(course.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MindSpaceTheme.textPrimary)
                    
                    HStack(spacing: 6) {
                        Text("\(course.totalSessions) sessions")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(MindSpaceTheme.textSecondary)
                        
                        if course.introVideo != nil {
                            Text("• Video Intro")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(MindSpaceTheme.success)
                        }
                    }
                }
                
                Spacer()
                
                if !isAvailable {
                    Text("Unavailable")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(MindSpaceTheme.danger)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(MindSpaceTheme.danger.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(MindSpaceTheme.textDisabled)
            }
        }
    }
    
    private func singlesCategoryRow(category: SinglesCategory, count: Int) -> some View {
        MindSpaceCard(padding: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(MindSpaceTheme.accent.opacity(0.25))
                        .frame(width: 44, height: 44)
                    Image(systemName: category.iconName.isEmpty ? "sparkles" : category.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(MindSpaceTheme.secondaryAccent)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(category.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MindSpaceTheme.textPrimary)
                    
                    Text("\(count) sessions available")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(MindSpaceTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(MindSpaceTheme.textDisabled)
            }
        }
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        let results = catalogService.search(query: searchText)
        
        return VStack(alignment: .leading, spacing: 14) {
            Text("Search Results")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(MindSpaceTheme.textPrimary)
                .padding(.horizontal, 20)
            
            if results.courses.isEmpty && results.sessions.isEmpty && results.singles.isEmpty {
                VStack(spacing: 8) {
                    Text("No results found for \"\(searchText)\"")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(MindSpaceTheme.textSecondary)
                    Text("Try searching for Basics, Stress, Sleep, Focus, or Anxiety.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(MindSpaceTheme.textDisabled)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
            
            // Courses
            ForEach(results.courses) { course in
                NavigationLink(destination: CourseDetailView(course: course)) {
                    MindSpaceCard(padding: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "book.fill")
                                .foregroundColor(MindSpaceTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.name)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(MindSpaceTheme.textPrimary)
                                Text("Course • \(course.totalSessions) sessions")
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(MindSpaceTheme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .accessibilityIdentifier("library.course.\(course.id)")
            }
            
            // Singles
            ForEach(results.singles) { single in
                let isAvail = LibraryPathResolver.shared.isFileAvailable(relativePath: single.relativePath)
                Button(action: {
                    HapticService.shared.medium()
                    let track = PlayableTrack(
                        id: single.id,
                        title: single.title,
                        courseName: single.category,
                        relativePath: single.relativePath,
                        duration: single.duration
                    )
                    playbackEngine.loadAndPlay(track: track)
                    playbackEngine.isFullPlayerPresented = true
                }) {
                    MindSpaceCard(padding: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(MindSpaceTheme.warning)
                                .font(.system(size: 20))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(single.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(MindSpaceTheme.textPrimary)
                                Text("\(single.category) • \(single.condensedDuration)")
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(MindSpaceTheme.textSecondary)
                            }
                            Spacer()
                            if !isAvail {
                                Text("Unavailable")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(MindSpaceTheme.danger)
                            }
                        }
                    }
                }
                .buttonStyle(.mindSpacePressable)
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Secondary Filters Sheet
    private var secondaryFiltersSheet: some View {
        NavigationStack {
            ZStack {
                MindSpaceTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Duration
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Duration")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(MindSpaceTheme.textPrimary)
                            
                            ForEach(DurationFilter.allCases) { opt in
                                filterRow(title: opt.rawValue, isSelected: selectedDuration == opt) {
                                    selectedDuration = opt
                                }
                            }
                        }
                        
                        Divider().background(MindSpaceTheme.divider)
                        
                        // Media
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Media Type")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(MindSpaceTheme.textPrimary)
                            
                            ForEach(MediaFilter.allCases) { opt in
                                filterRow(title: opt.rawValue, isSelected: selectedMedia == opt) {
                                    selectedMedia = opt
                                }
                            }
                        }
                        
                        Divider().background(MindSpaceTheme.divider)
                        
                        // Status
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Status & Favorites")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(MindSpaceTheme.textPrimary)
                            
                            ForEach(StatusFilter.allCases) { opt in
                                filterRow(title: opt.rawValue, isSelected: selectedStatus == opt) {
                                    selectedStatus = opt
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Filter Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        selectedDuration = .all
                        selectedMedia = .all
                        selectedStatus = .all
                    }
                    .foregroundColor(MindSpaceTheme.danger)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showFilterSheet = false
                    }
                    .foregroundColor(MindSpaceTheme.secondaryAccent)
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func filterRow(title: String, isSelected: Bool, onSelect: @escaping () -> Void) -> some View {
        Button(action: {
            HapticService.shared.selection()
            onSelect()
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? MindSpaceTheme.warning : MindSpaceTheme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MindSpaceTheme.warning)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func matchesFilters(course: CatalogCourse) -> Bool {
        if selectedFilter == .available && !LibraryPathResolver.shared.isCourseAvailable(course: course) {
            return false
        }
        if selectedMedia == .video && course.introVideo == nil && !course.sessions.contains(where: { !($0.videoAttachments ?? []).isEmpty }) {
            return false
        }
        if selectedStatus == .completed && !course.sessions.allSatisfy({ completedIDs.contains($0.id) }) {
            return false
        }
        if selectedStatus == .unplayed && course.sessions.contains(where: { completedIDs.contains($0.id) }) {
            return false
        }
        if selectedStatus == .favorites && !favoriteIDs.contains(course.id) {
            return false
        }
        return true
    }
    
    private func matchesFilters(session: SingleSession) -> Bool {
        if selectedFilter == .available && !LibraryPathResolver.shared.isFileAvailable(relativePath: session.relativePath) {
            return false
        }
        if !selectedDuration.matches(seconds: session.duration) {
            return false
        }
        if selectedMedia == .video { return false } // Single sessions are all audio
        if selectedStatus == .completed && !completedIDs.contains(session.id) { return false }
        if selectedStatus == .unplayed && completedIDs.contains(session.id) { return false }
        if selectedStatus == .favorites && !favoriteIDs.contains(session.id) { return false }
        return true
    }
    
}
