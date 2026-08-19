import SwiftUI

public enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case courses = "Courses"
    case singles = "Singles"
    case sos = "SOS"
    case sleep = "Sleep"
    
    public var id: String { rawValue }
}

/// Screen 2: Library & Category Explorer (Canonical Blueprint)
/// Reference: Mock Screen Codex.png
public struct LibraryView: View {
    @ObservedObject private var catalogService = CatalogService.shared
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    
    @State private var searchText = ""
    @State private var selectedFilter: LibraryFilter = .all
    
    public init() {}
    
    private var searchResults: (courses: [CatalogCourse], sessions: [CatalogSession], singles: [SingleSession]) {
        catalogService.search(query: searchText)
    }
    
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                CosmosTheme.spaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // MARK: - Header
                        Text("Library")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        
                        // MARK: - Search Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(CosmosTheme.textSecondary)
                            
                            TextField("Search courses, sessions, topics...", text: $searchText)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                                .autocorrectionDisabled()
                            
                            if isSearching {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(CosmosTheme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        // MARK: - Search Results (if searching)
                        if isSearching {
                            searchResultsView
                        } else {
                            // MARK: - Filter Chips
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
                            
                            // MARK: - Category Grid & Lists
                            categoryContentView
                        }
                        
                        Spacer(minLength: 80)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Category Content View
    @ViewBuilder
    private var categoryContentView: some View {
        VStack(spacing: 16) {
            // PACKS / COURSES CATEGORIES
            if selectedFilter == .all || selectedFilter == .courses {
                if let categories = catalogService.manifest?.categories {
                    VStack(spacing: 12) {
                        ForEach(categories) { category in
                            ForEach(category.courses) { course in
                                NavigationLink(destination: CourseDetailView(course: course)) {
                                    CategoryCardView(
                                        title: course.name,
                                        subtitle: category.name,
                                        sessionCountText: "\(course.totalSessions) sessions",
                                        planetStyle: planetStyle(for: category.name),
                                        action: {}
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
            
            // SINGLES CATEGORIES
            if selectedFilter == .all || selectedFilter == .singles || selectedFilter == .sos || selectedFilter == .sleep {
                if let singlesCats = catalogService.manifest?.singlesCategories {
                    let filtered = singlesCats.filter { cat in
                        if selectedFilter == .sos { return cat.name == "SOS" || cat.name.contains("Anxious") }
                        if selectedFilter == .sleep { return cat.name.contains("Sleep") || cat.name.contains("Good Night") || cat.name.contains("Unwind") }
                        return true
                    }
                    
                    VStack(spacing: 12) {
                        ForEach(filtered) { cat in
                            NavigationLink(destination: SinglesListView(category: cat, onSelectSession: { single in
                                let track = PlayableTrack(
                                    id: single.id,
                                    title: single.title,
                                    courseName: cat.name,
                                    relativePath: single.relativePath,
                                    duration: single.duration
                                )
                                playbackEngine.loadAndPlay(track: track)
                                playbackEngine.isFullPlayerPresented = true
                            })) {
                                CategoryCardView(
                                    title: cat.name,
                                    subtitle: cat.description,
                                    sessionCountText: "\(cat.sessions.count) tracks",
                                    planetStyle: cat.name.contains("Sleep") ? .crescentMoon : (cat.name == "SOS" ? .solarCoral : .electricBlue),
                                    action: {}
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Search Results View
    @ViewBuilder
    private var searchResultsView: some View {
        let results = searchResults
        let totalMatches = results.courses.count + results.sessions.count + results.singles.count
        
        VStack(alignment: .leading, spacing: 14) {
            Text("Found \(totalMatches) results")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(CosmosTheme.textSecondary)
                .padding(.horizontal, 20)
            
            if !results.courses.isEmpty {
                Text("Courses")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.starlightGold)
                    .padding(.horizontal, 20)
                
                ForEach(results.courses) { course in
                    NavigationLink(destination: CourseDetailView(course: course)) {
                        CategoryCardView(
                            title: course.name,
                            subtitle: course.description,
                            sessionCountText: "\(course.totalSessions) sessions",
                            planetStyle: .purpleRinged,
                            action: {}
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
            }
            
            if !results.sessions.isEmpty {
                Text("Sessions")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.starlightGold)
                    .padding(.horizontal, 20)
                
                ForEach(results.sessions) { session in
                    Button(action: {
                        let track = PlayableTrack(
                            id: session.id,
                            title: session.title,
                            relativePath: session.relativePath,
                            duration: session.duration,
                            videoAttachmentPath: session.videoAttachments?.first?.relativePath,
                            dayNumber: session.dayNumber
                        )
                        playbackEngine.loadAndPlay(track: track)
                        playbackEngine.isFullPlayerPresented = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                Text("Day \(session.dayNumber) • \(session.formattedDuration)")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(CosmosTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(CosmosTheme.cosmicPurple)
                        }
                        .padding(16)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
            }
            
            if !results.singles.isEmpty {
                Text("Singles")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.starlightGold)
                    .padding(.horizontal, 20)
                
                ForEach(results.singles) { single in
                    Button(action: {
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
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(single.title)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                Text("\(single.category) • \(single.formattedDuration)")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(CosmosTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(CosmosTheme.cosmicPurple)
                        }
                        .padding(16)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private func planetStyle(for categoryName: String) -> PlanetStyle {
        let lower = categoryName.lowercased()
        if lower.contains("foundation") || lower.contains("basics") { return .purpleRinged }
        if lower.contains("health") { return .auroraTeal }
        if lower.contains("happiness") { return .solarCoral }
        if lower.contains("work") || lower.contains("focus") { return .electricBlue }
        if lower.contains("sleep") { return .crescentMoon }
        if lower.contains("pro") { return .deepLavender }
        if lower.contains("sport") { return .auroraTeal }
        return .purpleRinged
    }
}
