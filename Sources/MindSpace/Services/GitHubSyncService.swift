import Foundation
import CryptoKit
import Combine

/// Progress state model for live syncing feedback
public struct SyncProgressState: Sendable, Equatable {
    public let isSyncing: Bool
    public let title: String
    public let completedTracks: Int
    public let totalTracks: Int
    public let fraction: Double
    public let errorMessage: String?
    public let successMessage: String?
}

/// Service managing authenticated content synchronization and selective downloads
/// from a private GitHub repository into Documents/MindSpaceLibrary/
@MainActor
public final class GitHubSyncService: ObservableObject {
    public static let shared = GitHubSyncService()
    
    private let repoKey = "github_sync_repo"
    private let patKey = "github_sync_pat"
    
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var activeCourseId: String? = nil
    @Published public private(set) var currentTaskTitle: String = ""
    @Published public private(set) var completedTracks: Int = 0
    @Published public private(set) var totalTracks: Int = 0
    @Published public private(set) var progressFraction: Double = 0.0
    @Published public private(set) var lastErrorMessage: String? = nil
    @Published public private(set) var lastSuccessMessage: String? = nil
    
    private var syncTask: Task<Void, Never>?
    private var isCancelled = false
    
    public init() {}
    
    // MARK: - Credential Configuration
    
    public var savedRepo: String {
        get {
            UserDefaults.standard.string(forKey: repoKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: repoKey)
            objectWillChange.send()
        }
    }
    
    public var savedPAT: String {
        get {
            KeychainManager.shared.get(key: patKey) ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                KeychainManager.shared.delete(key: patKey)
            } else {
                KeychainManager.shared.save(key: patKey, value: trimmed)
            }
            objectWillChange.send()
        }
    }
    
    public var isConfigured: Bool {
        !savedRepo.isEmpty && !savedPAT.isEmpty
    }
    
    // MARK: - Connection Testing
    
    public func testConnection() async -> (success: Bool, message: String) {
        guard isConfigured else {
            return (false, "Please enter both a GitHub Repository and a Personal Access Token.")
        }
        
        let repo = savedRepo.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "https://api.github.com/repos/\(repo)") else {
            return (false, "Invalid repository URL format.")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(savedPAT)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MindSpace-iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Unexpected network response from GitHub.")
            }
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let isPrivate = json["private"] as? Bool {
                    let visibility = isPrivate ? "Private Repository" : "Public Repository"
                    return (true, "Connected successfully to \(repo) (\(visibility)).")
                }
                return (true, "Connected successfully to \(repo).")
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return (false, "Authentication failed (HTTP \(httpResponse.statusCode)). Please check your Personal Access Token permissions.")
            } else if httpResponse.statusCode == 404 {
                return (false, "Repository '\(repo)' not found. Check repository name and PAT access.")
            } else {
                return (false, "GitHub returned HTTP status \(httpResponse.statusCode).")
            }
        } catch {
            return (false, "Connection error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Course Download (Selective)
    
    public func downloadCourse(course: CatalogCourse) {
        guard !isSyncing else { return }
        guard isConfigured else {
            self.lastErrorMessage = "GitHub repository and PAT token are required. Please configure in Settings."
            return
        }
        
        // Collect missing tracks for this course
        var missingItems: [(relativePath: String, sizeBytes: Int64, sha256: String, title: String)] = []
        
        if let intro = course.introVideo, !LibraryPathResolver.shared.isFileAvailable(relativePath: intro.relativePath) {
            missingItems.append((intro.relativePath, intro.sizeBytes, intro.sha256, "Intro Video"))
        }
        
        for session in course.sessions {
            if !LibraryPathResolver.shared.isFileAvailable(relativePath: session.relativePath) {
                missingItems.append((session.relativePath, session.sizeBytes, session.sha256, session.title))
            }
            for video in session.videoAttachments ?? [] {
                if !LibraryPathResolver.shared.isFileAvailable(relativePath: video.relativePath) {
                    missingItems.append((video.relativePath, video.sizeBytes, video.sha256, "\(session.title) (Video)"))
                }
            }
        }
        
        guard !missingItems.isEmpty else {
            self.lastSuccessMessage = "\(course.name) is already completely downloaded."
            return
        }
        
        self.activeCourseId = course.id
        startDownloadQueue(
            title: "Downloading \(course.name)",
            items: missingItems
        )
    }
    
    // MARK: - Smart Sync (Goal-Based)
    
    public func smartSync(goals: [String]) {
        guard !isSyncing else { return }
        guard isConfigured else {
            self.lastErrorMessage = "GitHub repository and PAT token are required. Please configure in Settings."
            return
        }
        
        guard let manifest = CatalogService.shared.manifest else {
            self.lastErrorMessage = "Catalog manifest not loaded."
            return
        }
        
        let normalizedGoals = Set(goals.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
        var targetCourses: [CatalogCourse] = []
        
        for category in manifest.categories {
            let catLower = category.name.lowercased()
            let isFoundation = catLower.contains("foundation") || catLower.contains("basics")
            let isGoalMatch = normalizedGoals.isEmpty || normalizedGoals.contains(catLower) || normalizedGoals.contains(where: { catLower.contains($0) })
            
            if isFoundation || isGoalMatch {
                targetCourses.append(contentsOf: category.courses)
            }
        }
        
        var missingItems: [(relativePath: String, sizeBytes: Int64, sha256: String, title: String)] = []
        
        for course in targetCourses {
            if let intro = course.introVideo, !LibraryPathResolver.shared.isFileAvailable(relativePath: intro.relativePath) {
                missingItems.append((intro.relativePath, intro.sizeBytes, intro.sha256, "\(course.name) Intro"))
            }
            for session in course.sessions {
                if !LibraryPathResolver.shared.isFileAvailable(relativePath: session.relativePath) {
                    missingItems.append((session.relativePath, session.sizeBytes, session.sha256, session.title))
                }
                for video in session.videoAttachments ?? [] {
                    if !LibraryPathResolver.shared.isFileAvailable(relativePath: video.relativePath) {
                        missingItems.append((video.relativePath, video.sizeBytes, video.sha256, "\(session.title) (Video)"))
                    }
                }
            }
        }
        
        guard !missingItems.isEmpty else {
            self.lastSuccessMessage = "Smart Sync complete: All goal-matched courses are already downloaded!"
            return
        }
        
        startDownloadQueue(
            title: "Smart Sync (\(targetCourses.count) Courses)",
            items: missingItems
        )
    }
    
    // MARK: - Download All (Full Catalog)
    
    public func downloadAll() {
        guard !isSyncing else { return }
        guard isConfigured else {
            self.lastErrorMessage = "GitHub repository and PAT token are required. Please configure in Settings."
            return
        }
        
        guard let manifest = CatalogService.shared.manifest else {
            self.lastErrorMessage = "Catalog manifest not loaded."
            return
        }
        
        var missingItems: [(relativePath: String, sizeBytes: Int64, sha256: String, title: String)] = []
        
        for category in manifest.categories {
            for course in category.courses {
                if let intro = course.introVideo, !LibraryPathResolver.shared.isFileAvailable(relativePath: intro.relativePath) {
                    missingItems.append((intro.relativePath, intro.sizeBytes, intro.sha256, "\(course.name) Intro"))
                }
                for session in course.sessions {
                    if !LibraryPathResolver.shared.isFileAvailable(relativePath: session.relativePath) {
                        missingItems.append((session.relativePath, session.sizeBytes, session.sha256, session.title))
                    }
                    for video in session.videoAttachments ?? [] {
                        if !LibraryPathResolver.shared.isFileAvailable(relativePath: video.relativePath) {
                            missingItems.append((video.relativePath, video.sizeBytes, video.sha256, "\(session.title) (Video)"))
                        }
                    }
                }
            }
        }
        
        for singleCat in manifest.singlesCategories {
            for session in singleCat.sessions {
                if !LibraryPathResolver.shared.isFileAvailable(relativePath: session.relativePath) {
                    missingItems.append((session.relativePath, session.sizeBytes, session.sha256, session.title))
                }
            }
        }
        
        guard !missingItems.isEmpty else {
            self.lastSuccessMessage = "All catalog media files are already downloaded."
            return
        }
        
        startDownloadQueue(
            title: "Full Library Sync",
            items: missingItems
        )
    }
    
    // MARK: - Download Singles Category
    
    public func downloadSinglesCategory(category: SinglesCategory) {
        guard !isSyncing else { return }
        guard isConfigured else {
            self.lastErrorMessage = "GitHub repository and PAT token are required. Please configure in Settings."
            return
        }
        
        var missingItems: [(relativePath: String, sizeBytes: Int64, sha256: String, title: String)] = []
        for session in category.sessions {
            if !LibraryPathResolver.shared.isFileAvailable(relativePath: session.relativePath) {
                missingItems.append((session.relativePath, session.sizeBytes, session.sha256, session.title))
            }
        }
        
        guard !missingItems.isEmpty else {
            self.lastSuccessMessage = "\(category.name) is already completely downloaded."
            return
        }
        
        self.activeCourseId = category.id
        startDownloadQueue(
            title: "Downloading \(category.name)",
            items: missingItems
        )
    }
    
    // MARK: - Download Single Session
    
    public func downloadSingleSession(session: SingleSession) {
        guard !isSyncing else { return }
        guard isConfigured else {
            self.lastErrorMessage = "GitHub repository and PAT token are required. Please configure in Settings."
            return
        }
        
        if LibraryPathResolver.shared.isFileAvailable(relativePath: session.relativePath) {
            self.lastSuccessMessage = "\(session.title) is already downloaded."
            return
        }
        
        self.activeCourseId = session.id
        startDownloadQueue(
            title: "Downloading \(session.title)",
            items: [(session.relativePath, session.sizeBytes, session.sha256, session.title)]
        )
    }
    
    // MARK: - Download Queue Engine
    
    private func startDownloadQueue(
        title: String,
        items: [(relativePath: String, sizeBytes: Int64, sha256: String, title: String)]
    ) {
        self.isSyncing = true
        self.isCancelled = false
        self.currentTaskTitle = title
        self.totalTracks = items.count
        self.completedTracks = 0
        self.progressFraction = 0.0
        self.lastErrorMessage = nil
        self.lastSuccessMessage = nil
        
        let repo = self.savedRepo.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let token = self.savedPAT
        
        self.syncTask = Task.detached(priority: .userInitiated) { [weak self] in
            let session = URLSession(configuration: .default)
            var successCount = 0
            var errorEncountered: String? = nil
            
            for item in items {
                if Task.isCancelled { break }
                
                let ok = await Self.downloadSingleFile(
                    relativePath: item.relativePath,
                    expectedSHA256: item.sha256,
                    repo: repo,
                    token: token,
                    session: session
                )
                
                if ok {
                    successCount += 1
                } else {
                    errorEncountered = "Failed to download \(item.title)"
                }
                
                let currentCompleted = successCount
                let total = items.count
                let fraction = Double(currentCompleted) / Double(total)
                
                await MainActor.run {
                    guard let self = self else { return }
                    self.completedTracks = currentCompleted
                    self.progressFraction = fraction
                }
            }
            
            // Hardening library folder after downloads
            LibraryPathResolver.shared.applyHardeningAndProtection()
            
            await MainActor.run {
                guard let self = self else { return }
                self.isSyncing = false
                self.activeCourseId = nil
                
                if self.isCancelled {
                    self.lastSuccessMessage = "Sync stopped (\(successCount) downloaded)."
                } else if let err = errorEncountered, successCount < items.count {
                    self.lastErrorMessage = "\(err) (\(successCount)/\(items.count) succeeded)."
                } else {
                    self.lastSuccessMessage = "Successfully downloaded \(successCount) tracks!"
                }
            }
        }
    }
    
    private static func downloadSingleFile(
        relativePath: String,
        expectedSHA256: String,
        repo: String,
        token: String,
        session: URLSession
    ) async -> Bool {
        // Encode path components safely for URL
        let pathParts = relativePath.split(separator: "/")
        let encodedParts = pathParts.compactMap { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) }
        let encodedRelativePath = encodedParts.joined(separator: "/")
        
        // Priority 1: raw.githubusercontent.com with Authorization
        let rawURLString = "https://raw.githubusercontent.com/\(repo)/main/\(encodedRelativePath)"
        guard let url = URL(string: rawURLString) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("MindSpace-iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60
        
        do {
            let (tempURL, response) = try await session.download(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                // Priority 2: Fallback to GitHub API Contents endpoint
                return await downloadViaContentsAPI(
                    relativePath: relativePath,
                    encodedRelativePath: encodedRelativePath,
                    expectedSHA256: expectedSHA256,
                    repo: repo,
                    token: token,
                    session: session
                )
            }
            
            return try verifyAndMoveFile(tempURL: tempURL, relativePath: relativePath, expectedSHA256: expectedSHA256)
        } catch {
            return await downloadViaContentsAPI(
                relativePath: relativePath,
                encodedRelativePath: encodedRelativePath,
                expectedSHA256: expectedSHA256,
                repo: repo,
                token: token,
                session: session
            )
        }
    }
    
    private static func downloadViaContentsAPI(
        relativePath: String,
        encodedRelativePath: String,
        expectedSHA256: String,
        repo: String,
        token: String,
        session: URLSession
    ) async -> Bool {
        let apiURLString = "https://api.github.com/repos/\(repo)/contents/\(encodedRelativePath)"
        guard let url = URL(string: apiURLString) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.raw", forHTTPHeaderField: "Accept")
        request.setValue("MindSpace-iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60
        
        do {
            let (tempURL, response) = try await session.download(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return false
            }
            return try verifyAndMoveFile(tempURL: tempURL, relativePath: relativePath, expectedSHA256: expectedSHA256)
        } catch {
            return false
        }
    }
    
    private static func verifyAndMoveFile(
        tempURL: URL,
        relativePath: String,
        expectedSHA256: String
    ) throws -> Bool {
        let fileManager = FileManager.default
        let destinationURL = LibraryPathResolver.shared.libraryDirectoryURL.appendingPathComponent(relativePath)
        
        // Optional SHA-256 verification
        if !expectedSHA256.isEmpty {
            if let fileData = try? Data(contentsOf: tempURL, options: .mappedIfSafe) {
                let digest = SHA256.hash(data: fileData)
                let hashString = digest.compactMap { String(format: "%02x", $0) }.joined()
                if hashString.lowercased() != expectedSHA256.lowercased() {
                    try? fileManager.removeItem(at: tempURL)
                    return false
                }
            }
        }
        
        // Create directory structure
        let parentDir = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.moveItem(at: tempURL, to: destinationURL)
        return true
    }
    
    public func cancelSync() {
        self.isCancelled = true
        self.syncTask?.cancel()
        self.syncTask = nil
        self.isSyncing = false
        self.activeCourseId = nil
    }
}
