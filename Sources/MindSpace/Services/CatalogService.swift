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
    
    public init() {
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
        sessionIndex.removeAll()
        courseIndex.removeAll()
        singleIndex.removeAll()
        
        for category in manifest.categories {
            for course in category.courses {
                courseIndex[course.id] = course
                for session in course.sessions {
                    sessionIndex[session.id] = session
                }
            }
        }
        
        for singleCat in manifest.singlesCategories {
            for session in singleCat.sessions {
                singleIndex[session.id] = session
            }
        }
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
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ([], [], [])
        }
        let lower = query.lowercased()
        
        let matchedCourses = courseIndex.values.filter {
            $0.name.lowercased().contains(lower) || $0.description.lowercased().contains(lower)
        }.sorted { $0.order < $1.order }
        
        let matchedSessions = sessionIndex.values.filter {
            $0.title.lowercased().contains(lower)
        }.sorted { $0.title < $1.title }
        
        let matchedSingles = singleIndex.values.filter {
            $0.title.lowercased().contains(lower) || $0.category.lowercased().contains(lower)
        }.sorted { $0.title < $1.title }
        
        return (matchedCourses, matchedSessions, matchedSingles)
    }
}
