import Foundation

/// Service responsible for loading, indexing, and querying the immutable offline catalog.
@MainActor
public final class CatalogService: ObservableObject {
    public static let shared = CatalogService()
    
    @Published public private(set) var manifest: CatalogManifest?
    @Published public private(set) var isLoading = false
    @Published public private(set) var loadError: String?
    
    // In-memory indexing for sub-millisecond search
    private var sessionIndex: [String: CatalogSession] = [:]
    private var courseIndex: [String: CatalogCourse] = [:]
    private var singleIndex: [String: SingleSession] = [:]
    
    // Pre-sorted and tokenized search records for 0-overhead query filtering
    private var sortedCourses: [(course: CatalogCourse, searchToken: String)] = []
    private var sortedSessions: [(session: CatalogSession, searchToken: String)] = []
    private var sortedSingles: [(single: SingleSession, searchToken: String)] = []
    
    public init() {
        #if DEBUG
        if UITestSupport.isEnabled {
            let fixture = UITestSupport.catalogManifest
            self.manifest = fixture
            buildIndices(fixture)
            return
        }
        #endif
        loadCatalog()
    }
    
    public func loadCatalog() {
        isLoading = true
        loadError = nil
        
        var catalogData: Data?
        
        // 1. Try Documents/MindSpaceLibrary/catalog.json
        let libraryURL = LibraryPathResolver.shared.libraryDirectoryURL.appendingPathComponent("catalog.json")
        if let data = try? Data(contentsOf: libraryURL) {
            catalogData = data
        }
        
        // 2. Try App Bundle Resources/catalog.json
        if catalogData == nil {
            if let bundleURL = Bundle.main.url(forResource: "catalog", withExtension: "json") {
                catalogData = try? Data(contentsOf: bundleURL)
            }
        }
        
        guard let data = catalogData else {
            self.loadError = "Catalog manifest not found in Library or Bundle."
            self.isLoading = false
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let decodedManifest = try decoder.decode(CatalogManifest.self, from: data)
            self.manifest = decodedManifest
            buildIndices(decodedManifest)
            self.isLoading = false
        } catch {
            self.loadError = "Failed to decode catalog: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    private func buildIndices(_ manifest: CatalogManifest) {
        sessionIndex.removeAll(keepingCapacity: true)
        courseIndex.removeAll(keepingCapacity: true)
        singleIndex.removeAll(keepingCapacity: true)
        
        var coursesList: [(CatalogCourse, String)] = []
        var sessionsList: [(CatalogSession, String)] = []
        var singlesList: [(SingleSession, String)] = []
        
        for category in manifest.categories {
            for course in category.courses {
                courseIndex[course.id] = course
                let courseToken = "\(course.name) \(course.description) \(category.name)".lowercased()
                coursesList.append((course, courseToken))
                
                for session in course.sessions {
                    sessionIndex[session.id] = session
                    let sessionToken = "\(session.title) \(course.name)".lowercased()
                    sessionsList.append((session, sessionToken))
                }
            }
        }
        
        for singleCat in manifest.singlesCategories {
            for session in singleCat.sessions {
                singleIndex[session.id] = session
                let singleToken = "\(session.title) \(session.category) \(session.subCategory ?? "")".lowercased()
                singlesList.append((session, singleToken))
            }
        }
        
        self.sortedCourses = coursesList.sorted { $0.0.order < $1.0.order }
        self.sortedSessions = sessionsList.sorted { $0.0.title < $1.0.title }
        self.sortedSingles = singlesList.sorted { $0.0.title < $1.0.title }
    }
    
    // MARK: - Query APIs
    
    public func getCourse(by id: String) -> CatalogCourse? {
        courseIndex[id]
    }
    
    public func getSession(by id: String) -> CatalogSession? {
        sessionIndex[id]
    }
    
    public func getSingleSession(by id: String) -> SingleSession? {
        singleIndex[id]
    }
    
    public func search(query: String) -> (courses: [CatalogCourse], sessions: [CatalogSession], singles: [SingleSession]) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ([], [], [])
        }
        let lower = trimmed.lowercased()
        
        let matchedCourses = sortedCourses
            .filter { $0.searchToken.contains(lower) }
            .map { $0.course }
        
        let matchedSessions = sortedSessions
            .filter { $0.searchToken.contains(lower) }
            .map { $0.session }
        
        let matchedSingles = sortedSingles
            .filter { $0.searchToken.contains(lower) }
            .map { $0.single }
        
        return (matchedCourses, matchedSessions, matchedSingles)
    }
}
