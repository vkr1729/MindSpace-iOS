import Foundation
import CryptoKit

public enum CatalogLoadError: Error, Sendable, Equatable {
    case notFound
    case decodeFailed(String)
    case schemaMismatch(found: Int, expected: Int)

    public var message: String {
        switch self {
        case .notFound:
            return "Catalog manifest not found in Library or Bundle."
        case .decodeFailed(let detail):
            return "Failed to decode catalog: \(detail)"
        case .schemaMismatch(let found, let expected):
            return "Catalog schema v\(found) isn't supported by this app (expects v\(expected)). Update the app to read this library."
        }
    }
}

/// Service responsible for loading, indexing, and querying the immutable offline catalog.
@MainActor
public final class CatalogService: ObservableObject {
    public static let shared = CatalogService()
    
    @Published public private(set) var manifest: CatalogManifest?
    @Published public private(set) var isLoading = false
    @Published public private(set) var loadError: String?
    @Published public private(set) var loadWarning: String?
    
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

    /// Reloads the catalog and reports completion on the main actor so
    /// callers (rescan, verify) can await the fresh manifest first.
    @discardableResult
    public func reloadCatalog() async -> Bool {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) { [weak self] in
                let result = Self.loadCatalogData()
                await MainActor.run {
                    guard let self = self else {
                        continuation.resume(returning: false)
                        return
                    }
                    switch result {
                    case .success(let (manifest, warning)):
                        self.manifest = manifest
                        self.buildIndices(manifest)
                        self.loadWarning = warning
                        self.isLoading = false
                        continuation.resume(returning: true)
                    case .failure(let error):
                        self.loadError = error.message
                        self.isLoading = false
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    public func loadCatalog() {
        isLoading = true
        loadError = nil
        loadWarning = nil

        Task.detached(priority: .userInitiated) { [weak self] in
            let result = Self.loadCatalogData()
            await MainActor.run {
                guard let self = self else { return }
                switch result {
                case .success(let (manifest, warning)):
                    self.manifest = manifest
                    self.buildIndices(manifest)
                    self.loadWarning = warning
                    self.isLoading = false
                case .failure(let error):
                    self.loadError = error.message
                    self.isLoading = false
                }
            }
        }
    }

    private nonisolated static func loadCatalogData() -> Result<(CatalogManifest, String?), CatalogLoadError> {
        var catalogData: Data?
        var catalogSource = "bundle"

        // 1. Try Documents/MindSpaceLibrary/catalog.json — only if it matches
        // the shipped bundle hash. An unverifiable sidecar is never trusted.
        let libraryURL = LibraryPathResolver.shared.libraryDirectoryURL.appendingPathComponent("catalog.json")
        if let data = try? Data(contentsOf: libraryURL),
           Self.isTrustedCatalogData(data) {
            catalogData = data
            catalogSource = "documents-verified"
        }

        // 2. App Bundle Resources/catalog.json
        if catalogData == nil {
            if let bundleURL = Bundle.main.url(forResource: "catalog", withExtension: "json") {
                catalogData = try? Data(contentsOf: bundleURL)
                catalogSource = "bundle"
            }
        }

        guard let data = catalogData else {
            return .failure(.notFound)
        }

        do {
            let decodedManifest = try JSONDecoder().decode(CatalogManifest.self, from: data)
            guard decodedManifest.schemaVersion == ProgressTransferManager.supportedCatalogSchemaVersion else {
                return .failure(.schemaMismatch(
                    found: decodedManifest.schemaVersion,
                    expected: ProgressTransferManager.supportedCatalogSchemaVersion
                ))
            }
            var warning: String?
            if catalogSource == "bundle",
               FileManager.default.fileExists(atPath: libraryURL.path),
               let sidecar = try? Data(contentsOf: libraryURL),
               !Self.isTrustedCatalogData(sidecar) {
                warning = "Documents catalog.json failed hash verification; using bundled catalog."
            }
            return .success((decodedManifest, warning))
        } catch {
            return .failure(.decodeFailed(error.localizedDescription))
        }
    }

    /// A Documents sidecar catalog is trusted only when its SHA-256 matches the
    /// hash shipped with the bundle. Keeps a poisoned sidecar from redirecting
    /// all downloads.
    private nonisolated static func isTrustedCatalogData(_ data: Data) -> Bool {
        guard let hashURL = Bundle.main.url(forResource: "catalog", withExtension: "sha256"),
              let hashLine = try? String(contentsOf: hashURL, encoding: .utf8) else {
            return false
        }
        let expected = hashLine.split(separator: " ").first.map(String.init)?.lowercased() ?? ""
        guard !expected.isEmpty else { return false }
        let digest = SHA256.hash(data: data)
        let actual = digest.compactMap { String(format: "%02x", $0) }.joined().lowercased()
        return actual == expected
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
