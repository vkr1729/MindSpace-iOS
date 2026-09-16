import Foundation
import CryptoKit
import Combine
import UIKit

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

/// One file's outcome inside a download queue, for the per-file error list.
public struct SyncFileResult: Sendable, Equatable, Identifiable {
    public var id: String { relativePath }
    public let relativePath: String
    public let title: String
    public let succeeded: Bool
    public let attempts: Int
    public let errorMessage: String?
}

/// Classifies a download failure so the queue can decide retry vs report.
public enum SyncDownloadFailure: Sendable, Equatable {
    case httpStatus(Int)
    case network(Error)
    case verification(String)
    case cancelled

    public static func == (lhs: SyncDownloadFailure, rhs: SyncDownloadFailure) -> Bool {
        switch (lhs, rhs) {
        case (.httpStatus(let a), .httpStatus(let b)): return a == b
        case (.network, .network): return true
        case (.verification(let a), .verification(let b)): return a == b
        case (.cancelled, .cancelled): return true
        default: return false
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .cancelled, .verification: return false
        case .httpStatus(let code): return code == 408 || code == 429 || code >= 500
        case .network: return true
        }
    }

    public var message: String {
        switch self {
        case .httpStatus(let code): return "HTTP \(code)"
        case .network(let error): return error.localizedDescription
        case .verification(let reason): return reason
        case .cancelled: return "cancelled"
        }
    }
}

/// Service managing authenticated content synchronization and selective downloads
/// from a private GitHub repository into Documents/MindSpaceLibrary/
@MainActor
public final class GitHubSyncService: ObservableObject {
    public static let shared = GitHubSyncService()

    nonisolated(unsafe) private static let foregroundSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60 * 60
        return URLSession(configuration: config)
    }()
    
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
    @Published public private(set) var fileResults: [SyncFileResult] = []
    @Published public private(set) var failedFiles: [SyncFileResult] = []

    public static let maxAttemptsPerFile = 3
    
    private var syncTask: Task<Void, Never>?
    private var isCancelled = false
    
    public init() {}
    
    // MARK: - Credential Configuration
    
    public var savedRepo: String {
        get {
            UserDefaults.standard.string(forKey: repoKey) ?? "vkr1729/MindSpace-Content"
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
            let session = Self.foregroundSession
            let backgroundTaskID: UIBackgroundTaskIdentifier = await MainActor.run { [weak self] in
                UIApplication.shared.beginBackgroundTask(withName: "MindSpaceSync") { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.cancelSync()
                    }
                }
            }
            var successCount = 0
            var processedCount = 0
            var results: [SyncFileResult] = []

            for item in items {
                if Task.isCancelled { break }

                let outcome = await Self.downloadSingleFileWithRetry(
                    relativePath: item.relativePath,
                    expectedSHA256: item.sha256,
                    title: item.title,
                    repo: repo,
                    token: token,
                    session: session
                )
                processedCount += 1
                if outcome.succeeded {
                    successCount += 1
                }
                results.append(outcome)

                let done = processedCount
                let total = items.count
                let fraction = total > 0 ? Double(done) / Double(total) : 1.0

                await MainActor.run {
                    guard let self = self else { return }
                    self.completedTracks = successCount
                    self.totalTracks = total
                    self.progressFraction = fraction
                }
            }

            // Hardening library folder after downloads
            LibraryPathResolver.shared.applyHardeningAndProtection()

            let finishedTaskID = backgroundTaskID
            let finalSuccessCount = successCount
            let finalTotalCount = items.count
            let finalResults = results
            await MainActor.run { [weak self] in
                if let self = self {
                    self.isSyncing = false
                    self.activeCourseId = nil
                    self.fileResults = finalResults
                    self.failedFiles = finalResults.filter { !$0.succeeded }

                    if self.isCancelled {
                        self.lastSuccessMessage = "Sync stopped (\(finalSuccessCount) downloaded)."
                    } else if finalSuccessCount < finalTotalCount {
                        let failed = finalResults.filter { !$0.succeeded }
                        let names = failed.prefix(3).map { $0.title }.joined(separator: ", ")
                        let more = failed.count > 3 ? " (+\(failed.count - 3) more)" : ""
                        self.lastErrorMessage = "\(finalSuccessCount)/\(finalTotalCount) downloaded. Failed: \(names)\(more)."
                    } else {
                        self.lastSuccessMessage = "Successfully downloaded \(finalSuccessCount) tracks!"
                    }
                }
                if finishedTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(finishedTaskID)
                }
            }
        }
    }
    
    // MARK: - Download Queue Engine

    /// Downloads one file with bounded retries and exponential backoff.
    /// Retryable failures (flaky network, 408/429/5xx) retry up to
    /// `maxAttemptsPerFile`; verification failures and cancels do not.
    static func downloadSingleFileWithRetry(
        relativePath: String,
        expectedSHA256: String,
        title: String,
        repo: String,
        token: String,
        session: URLSession
    ) async -> SyncFileResult {
        var attempts = 0
        var lastFailure: SyncDownloadFailure = .network(URLError(.unknown))
        while attempts < maxAttemptsPerFile {
            if Task.isCancelled {
                return SyncFileResult(
                    relativePath: relativePath,
                    title: title,
                    succeeded: false,
                    attempts: max(attempts, 1),
                    errorMessage: SyncDownloadFailure.cancelled.message
                )
            }
            attempts += 1
            let failure = await downloadSingleFileAttempt(
                relativePath: relativePath,
                expectedSHA256: expectedSHA256,
                repo: repo,
                token: token,
                session: session
            )
            guard let failure else {
                return SyncFileResult(
                    relativePath: relativePath,
                    title: title,
                    succeeded: true,
                    attempts: attempts,
                    errorMessage: nil
                )
            }
            lastFailure = failure
            guard failure.isRetryable, attempts < maxAttemptsPerFile else { break }
            let backoffNanoseconds = UInt64(500_000_000 * (1 << (attempts - 1)))
            try? await Task.sleep(nanoseconds: backoffNanoseconds)
        }
        return SyncFileResult(
            relativePath: relativePath,
            title: title,
            succeeded: false,
            attempts: attempts,
            errorMessage: lastFailure.message
        )
    }

    /// One attempt: raw host first, Contents API fallback. Returns nil on success.
    private static func downloadSingleFileAttempt(
        relativePath: String,
        expectedSHA256: String,
        repo: String,
        token: String,
        session: URLSession
    ) async -> SyncDownloadFailure? {
        // Encode path components safely for URL
        let pathParts = relativePath.split(separator: "/")
        let encodedParts = pathParts.compactMap { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) }
        let encodedRelativePath = encodedParts.joined(separator: "/")
        
        // Priority 1: raw.githubusercontent.com with Authorization
        let rawURLString = "https://raw.githubusercontent.com/\(repo)/main/\(encodedRelativePath)"
        guard let url = URL(string: rawURLString) else {
            return .verification("invalid download URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("MindSpace-iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60

        do {
            let (tempURL, response) = try await session.download(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                return verifyAndMoveFailure(tempURL: tempURL, relativePath: relativePath, expectedSHA256: expectedSHA256)
            }
            if let httpResponse = response as? HTTPURLResponse {
                let fallback = await downloadViaContentsAPI(
                    relativePath: relativePath,
                    encodedRelativePath: encodedRelativePath,
                    expectedSHA256: expectedSHA256,
                    repo: repo,
                    token: token,
                    session: session
                )
                return fallback ?? .httpStatus(httpResponse.statusCode)
            }
            return await downloadViaContentsAPI(
                relativePath: relativePath,
                encodedRelativePath: encodedRelativePath,
                expectedSHA256: expectedSHA256,
                repo: repo,
                token: token,
                session: session
            )
        } catch {
            if Task.isCancelled {
                return .cancelled
            }
            if let urlError = error as? URLError {
                let fallback = await downloadViaContentsAPI(
                    relativePath: relativePath,
                    encodedRelativePath: encodedRelativePath,
                    expectedSHA256: expectedSHA256,
                    repo: repo,
                    token: token,
                    session: session
                )
                return fallback ?? .network(urlError)
            }
            let fallback = await downloadViaContentsAPI(
                relativePath: relativePath,
                encodedRelativePath: encodedRelativePath,
                expectedSHA256: expectedSHA256,
                repo: repo,
                token: token,
                session: session
            )
            return fallback ?? .network(error)
        }
    }
    
    private static func downloadViaContentsAPI(
        relativePath: String,
        encodedRelativePath: String,
        expectedSHA256: String,
        repo: String,
        token: String,
        session: URLSession
    ) async -> SyncDownloadFailure? {
        let apiURLString = "https://api.github.com/repos/\(repo)/contents/\(encodedRelativePath)"
        guard let url = URL(string: apiURLString) else {
            return .verification("invalid Contents API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.raw", forHTTPHeaderField: "Accept")
        request.setValue("MindSpace-iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60

        do {
            let (tempURL, response) = try await session.download(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                if let httpResponse = response as? HTTPURLResponse {
                    return .httpStatus(httpResponse.statusCode)
                }
                return .network(URLError(.badServerResponse))
            }
            return verifyAndMoveFailure(tempURL: tempURL, relativePath: relativePath, expectedSHA256: expectedSHA256)
        } catch {
            if Task.isCancelled {
                return .cancelled
            }
            return .network(error)
        }
    }

    /// Installs a downloaded file after mandatory hash verification.
    /// Returns nil on success; callers surface the failure for the error list.
    private static func verifyAndMoveFailure(
        tempURL: URL,
        relativePath: String,
        expectedSHA256: String
    ) -> SyncDownloadFailure? {
        guard LibraryPathResolver.isSafeRelativePath(relativePath) else {
            try? FileManager.default.removeItem(at: tempURL)
            return .verification("unsafe relative path")
        }
        let fileManager = FileManager.default
        let destinationURL = LibraryPathResolver.shared.libraryDirectoryURL.appendingPathComponent(relativePath)

        // SHA-256 verification is mandatory when a hash is shipped; an unreadable
        // or mismatched file must never be installed.
        if !expectedSHA256.isEmpty {
            guard let hashString = LibraryPathResolver.streamSHA256Hex(of: tempURL),
                  hashString.lowercased() == expectedSHA256.lowercased() else {
                try? fileManager.removeItem(at: tempURL)
                return .verification("SHA-256 mismatch for \(relativePath)")
            }
        } else {
            try? fileManager.removeItem(at: tempURL)
            return .verification("missing expected SHA-256 for \(relativePath)")
        }

        do {
            // Create directory structure
            let parentDir = destinationURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: tempURL, backupItemName: nil, options: .usingNewMetadataOnly)
            } else {
                try fileManager.moveItem(at: tempURL, to: destinationURL)
            }
            return nil
        } catch {
            try? fileManager.removeItem(at: tempURL)
            return .verification("install failed for \(relativePath): \(error.localizedDescription)")
        }
    }

    public func cancelSync() {
        self.isCancelled = true
        self.syncTask?.cancel()
        self.syncTask = nil
        self.isSyncing = false
        self.activeCourseId = nil
    }
}
