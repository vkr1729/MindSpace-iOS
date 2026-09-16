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

/// Screen 2: Elevated Library & Category Explorer with 8 Pack Categories, 15 Singles Categories & Multi-Dimensional Filters
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

    @Binding private var path: NavigationPath

    public init(path: Binding<NavigationPath>? = nil) {
        if let path {
            _path = path
        } else {
            _path = .constant(NavigationPath())
        }
    }
    
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
        NavigationStack(path: $path) {
            ZStack {
                CosmosTheme.spaceBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // MARK: - Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Library")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            
                            Text("Explore 8 Pack categories, 15 Singles categories & 275+ hours")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // MARK: - Search Bar & Filter Button
                        HStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(CosmosTheme.textSecondary)
                                
                                TextField("Search courses, singles, topics...", text: $searchText)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                    .autocorrectionDisabled()
                                
                                if isSearching {
                                    Button(action: {
                                        HapticService.shared.light()
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(CosmosTheme.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(CosmosTheme.spaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(isSearching ? CosmosTheme.cosmicPurple.opacity(0.6) : CosmosTheme.spaceCardBorder, lineWidth: 1)
                            )
                            
                            // Secondary Filters Button
                            Button(action: {
                                HapticService.shared.light()
                                showFilterSheet.toggle()
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(hasActiveSecondaryFilters ? CosmosTheme.cosmicPurple : CosmosTheme.spaceCard)
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                                        )
                                    
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(hasActiveSecondaryFilters ? .white : CosmosTheme.textPrimary)
                                }
                            }
                            .buttonStyle(.cosmicPressable)
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
            Text("Filters:")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(CosmosTheme.textSecondary)
            
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
                .foregroundColor(CosmosTheme.starlightGold)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(CosmosTheme.starlightGold)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(CosmosTheme.cosmicPurple.opacity(0.3))
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
                            Text("Course Packs (\(categoriesWithMatches.count) Categories)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                                .padding(.horizontal, 20)
                            
                            ForEach(categoriesWithMatches) { category in
                                let matchingCourses = category.courses.filter { matchesFilters(course: $0) }
                                if !matchingCourses.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(category.name)
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(CosmosTheme.moonLavender)
                                            Spacer()
                                            Text("\(matchingCourses.count) courses")
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(CosmosTheme.textSecondary)
                                        }
                                        .padding(.horizontal, 20)
                                        
                                        ForEach(matchingCourses) { course in
                                            NavigationLink(destination: CourseDetailView(course: course)) {
                                                courseRow(course: course, category: category)
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.horizontal, 20)
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
                            Text("Singles (\(categoriesWithMatches.count) Categories)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
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
        
        return CosmicCard(padding: 14) {
            HStack(spacing: 14) {
                CelestialPlanetView(style: planetStyle(for: category.name), size: 44, hasRings: category.name.contains("Foundation"))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(course.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                    
                    HStack(spacing: 6) {
                        Text("\(course.totalSessions) sessions")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                        
                        if course.introVideo != nil {
                            Text("• Video Intro")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(CosmosTheme.auroraTeal)
                        }
                    }
                }
                
                Spacer()
                
                if !isAvailable {
                    Text("Unavailable")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.solarCoral)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(CosmosTheme.solarCoral.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(CosmosTheme.textDisabled)
            }
        }
    }
    
    private func singlesCategoryRow(category: SinglesCategory, count: Int) -> some View {
        CosmicCard(padding: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(CosmosTheme.cosmicPurple.opacity(0.25))
                        .frame(width: 44, height: 44)
                    Image(systemName: category.iconName.isEmpty ? "sparkles" : category.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(CosmosTheme.moonLavender)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(category.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                    
                    Text("\(count) sessions available")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(CosmosTheme.textDisabled)
            }
        }
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        let results = catalogService.search(query: searchText)
        
        return VStack(alignment: .leading, spacing: 14) {
            Text("Search Results")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(CosmosTheme.textPrimary)
                .padding(.horizontal, 20)
            
            if results.courses.isEmpty && results.sessions.isEmpty && results.singles.isEmpty {
                VStack(spacing: 8) {
                    Text("No results found for \"\(searchText)\"")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                    Text("Try searching for Basics, Stress, Sleep, Focus, or Anxiety.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(CosmosTheme.textDisabled)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
            
            // Courses
            ForEach(results.courses) { course in
                NavigationLink(destination: CourseDetailView(course: course)) {
                    CosmicCard(padding: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "book.fill")
                                .foregroundColor(CosmosTheme.cosmicPurple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.name)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                Text("Course • \(course.totalSessions) sessions")
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(CosmosTheme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
            
            // Sessions
            ForEach(results.sessions) { session in
                Button(action: {
                    HapticService.shared.medium()
                    let track = PlayableTrack(
                        id: session.id,
                        title: session.title,
                        courseName: nil,
                        relativePath: session.relativePath,
                        duration: session.duration,
                        videoAttachmentPath: session.videoAttachments?.first?.relativePath,
                        dayNumber: session.dayNumber,
                        videoDuration: session.videoAttachments?.first?.duration,
                        contentType: "meditation"
                    )
                    playbackEngine.loadAndPlay(track: track)
                    playbackEngine.isFullPlayerPresented = true
                }) {
                    CosmicCard(padding: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "circle.grid.cross.fill")
                                .foregroundColor(CosmosTheme.celestialBlue)
                                .font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                Text("Day \(session.dayNumber) • \(session.condensedDuration)")
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(CosmosTheme.textSecondary)
                            }
                            Spacer()
                            if !LibraryPathResolver.shared.isFileAvailable(relativePath: session.relativePath) {
                                Text("Unavailable")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.solarCoral)
                            }
                        }
                    }
                }
                .buttonStyle(.cosmicPressable)
                .padding(.horizontal, 20)
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
                    CosmicCard(padding: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(CosmosTheme.starlightGold)
                                .font(.system(size: 20))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(single.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                Text("\(single.category) • \(single.condensedDuration)")
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(CosmosTheme.textSecondary)
                            }
                            Spacer()
                            if !isAvail {
                                Text("Unavailable")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.solarCoral)
                            }
                        }
                    }
                }
                .buttonStyle(.cosmicPressable)
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Secondary Filters Sheet
    private var secondaryFiltersSheet: some View {
        NavigationStack {
            ZStack {
                CosmosTheme.spaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Duration
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Duration")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            
                            ForEach(DurationFilter.allCases) { opt in
                                filterRow(title: opt.rawValue, isSelected: selectedDuration == opt) {
                                    selectedDuration = opt
                                }
                            }
                        }
                        
                        Divider().background(CosmosTheme.spaceCardBorder)
                        
                        // Media
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Media Type")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            
                            ForEach(MediaFilter.allCases) { opt in
                                filterRow(title: opt.rawValue, isSelected: selectedMedia == opt) {
                                    selectedMedia = opt
                                }
                            }
                        }
                        
                        Divider().background(CosmosTheme.spaceCardBorder)
                        
                        // Status
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Status & Favorites")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            
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
                    .foregroundColor(CosmosTheme.solarCoral)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showFilterSheet = false
                    }
                    .foregroundColor(CosmosTheme.moonLavender)
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
                    .foregroundColor(isSelected ? CosmosTheme.starlightGold : CosmosTheme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(CosmosTheme.starlightGold)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func matchesFilters(course: CatalogCourse) -> Bool {
        if selectedFilter == .available && !LibraryPathResolver.shared.isCourseAvailable(course: course) {
            return false
        }
        if selectedDuration != .all,
           !course.sessions.contains(where: { selectedDuration.matches(seconds: $0.duration) }) {
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
    
    private func planetStyle(for categoryName: String) -> CelestialPlanetStyle {
        switch categoryName.lowercased() {
        case let name where name.contains("foundation"): return .purpleRinged
        case let name where name.contains("health"): return .auroraTeal
        case let name where name.contains("happiness"): return .goldenSun
        case let name where name.contains("work"): return .electricBlue
        default: return .deepCosmos
        }
    }
}
