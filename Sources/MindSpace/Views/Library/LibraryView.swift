import SwiftUI

public enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case courses = "Courses"
    case singles = "Singles"
    case sos = "SOS"
    case sleep = "Sleep"
    
    public var id: String { rawValue }
}

/// Screen 2: Elevated Library & Category Explorer
/// Reference: Mock Screen Codex.png & UI/UX Pro Max Design Intelligence
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
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // MARK: - Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Library")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            
                            Text("Explore 275+ hours of celestial meditations & courses")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // MARK: - Search Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(CosmosTheme.textSecondary)
                            
                            TextField("Search courses, sessions, topics...", text: $searchText)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                                .autocorrectionDisabled()
                                .onChange(of: searchText) { _, newValue in
                                    if !newValue.isEmpty {
                                        HapticService.shared.soft()
                                    }
                                }
                            
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isSearching ? CosmosTheme.cosmicPurple.opacity(0.6) : CosmosTheme.spaceCardBorder, lineWidth: 1)
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
                        
                        Spacer(minLength: 90)
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
                                        planetStyle: planetStyle(for: category.name)
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
                                HapticService.shared.medium()
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
                                    planetStyle: planetStyle(for: cat.name)
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
            if totalMatches == 0 {
                // Rich Zero Search State
                CosmicCard(padding: 24) {
                    VStack(spacing: 12) {
                        CelestialPlanetView(style: .crescentMoon, size: 52, hasRings: false)
                        
                        Text("No meditations found")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                        
                        Text("Try searching for 'anxiety', 'sleep', 'basics', 'breathe', or 'reset'")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            } else {
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
                                planetStyle: planetStyle(for: course.name)
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
                            HapticService.shared.medium()
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
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                    Text("Day \(session.dayNumber) • \(session.formattedDuration)")
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(CosmosTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 28))
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
                        .buttonStyle(.cosmicPressable)
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
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(single.title)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                    Text("\(single.category) • \(single.formattedDuration)")
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(CosmosTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 28))
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
                        .buttonStyle(.cosmicPressable)
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
    
    private func planetStyle(for categoryName: String) -> PlanetStyle {
        let lower = categoryName.lowercased()
        if lower.contains("foundation") || lower.contains("basics") { return .purpleRinged }
        if lower.contains("health") || lower.contains("anxiety") || lower.contains("stress") { return .auroraTeal }
        if lower.contains("happiness") || lower.contains("relationships") || lower.contains("kindness") { return .solarCoral }
        if lower.contains("work") || lower.contains("focus") || lower.contains("productivity") { return .electricBlue }
        if lower.contains("sleep") || lower.contains("night") || lower.contains("unwind") { return .crescentMoon }
        if lower.contains("brave") || lower.contains("grief") || lower.contains("anger") || lower.contains("sos") { return .brave }
        if lower.contains("student") { return .deepLavender }
        if lower.contains("pro") { return .pro }
        if lower.contains("sport") { return .sport }
        return .purpleRinged
    }
}
