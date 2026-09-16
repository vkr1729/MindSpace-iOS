import Foundation
import AVFoundation
import CryptoKit

/// Verification report representing the real state of media files on disk.
public struct LibraryVerificationReport: Sendable, Equatable {
    public let totalTracks: Int
    public let foundCount: Int
    public let missingCount: Int
    public let sizeMismatchedCount: Int
    public let checksumMismatchedCount: Int
    public let missingPaths: [String]
    public let totalHoursFormatted: String
    public let isHardened: Bool
    public let verifiedAt: Date
    
    public init(
        totalTracks: Int,
        foundCount: Int,
        missingCount: Int,
        sizeMismatchedCount: Int,
        checksumMismatchedCount: Int,
        missingPaths: [String],
        totalHoursFormatted: String,
        isHardened: Bool,
        verifiedAt: Date = Date()
    ) {
        self.totalTracks = totalTracks
        self.foundCount = foundCount
        self.missingCount = missingCount
        self.sizeMismatchedCount = sizeMismatchedCount
        self.checksumMismatchedCount = checksumMismatchedCount
        self.missingPaths = missingPaths
        self.totalHoursFormatted = totalHoursFormatted
        self.isHardened = isHardened
        self.verifiedAt = verifiedAt
    }
    
    public var isFullyVerified: Bool {
        totalTracks > 0 && missingCount == 0 && sizeMismatchedCount == 0 && checksumMismatchedCount == 0 && isHardened
    }
}

/// Centralized resolver that turns relative media paths into absolute file URLs inside
/// Documents/MindSpaceLibrary/ with sandboxing and file-protection safeguards.
public struct LibraryPathResolver: Sendable {
    public static let shared = LibraryPathResolver()
    
    public let libraryFolderName = "MindSpaceLibrary"
    
    private static let _cachedLibraryURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return docs.appendingPathComponent("MindSpaceLibrary", isDirectory: true)
    }()
    
    /// Rejects catalog-supplied paths that escape the library sandbox.
    public static func isSafeRelativePath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("/"),
              !trimmed.hasPrefix("~"),
              !trimmed.contains("\0") else { return false }
        let parts = trimmed.split(separator: "/").map(String.init)
        guard !parts.isEmpty else { return false }
        return !parts.contains("..")
    }
    
    public init() {}
    
    /// Root directory URL for user-supplied media library in Documents/
    public var libraryDirectoryURL: URL {
        Self._cachedLibraryURL
    }
    
    /// Resolves a relative path (e.g. "Packs/1 - Foundation/Basics/Day 01.mp3") to a local URL.
    /// Checks Documents/MindSpaceLibrary/ first, then Bundle.main as a fallback.
    /// Returns nil if the file is missing from both locations.
    public func resolveURL(for relativePath: String) -> URL? {
        guard Self.isSafeRelativePath(relativePath) else { return nil }
        let fileURL = libraryDirectoryURL.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        // Check main bundle (useful for testing or bundled assets)
        if let bundleURL = Bundle.main.url(forResource: relativePath, withExtension: nil) {
            if FileManager.default.fileExists(atPath: bundleURL.path) {
                return bundleURL
            }
        }
        
        return nil
    }
    
    /// Resolves an authenticated AVURLAsset for on-demand online streaming from private GitHub repository.
    /// Uses the Contents API URL form so the Authorization header survives
    /// redirects: raw.githubusercontent.com redirects and AVFoundation does
    /// not forward custom headers across them, but api.github.com serves the
    /// bytes directly with `Accept: application/vnd.github.raw`.
    public func resolveRemoteStreamAsset(for relativePath: String) -> (asset: AVURLAsset, remoteURL: URL)? {
        guard Self.isSafeRelativePath(relativePath) else { return nil }
        let pat = (KeychainManager.shared.get(key: "github_sync_pat") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pat.isEmpty else {
            return nil
        }

        let repo = (UserDefaults.standard.string(forKey: "github_sync_repo") ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !repo.isEmpty else {
            return nil
        }

        // URL encode each path component individually so slashes are preserved
        let components = relativePath.split(separator: "/").map {
            $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }
        let encodedPath = components.joined(separator: "/")

        guard let remoteURL = URL(string: "https://api.github.com/repos/\(repo)/contents/\(encodedPath)") else {
            return nil
        }

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let headers: [String: String] = [
            "Authorization": "Bearer \(pat)",
            "Accept": "application/vnd.github.raw",
            "User-Agent": "MindSpace-iOS/\(appVersion)"
        ]

        let asset = AVURLAsset(
            url: remoteURL,
            options: [
                "AVURLAssetHTTPHeaderFieldsKey": headers
            ]
        )
        return (asset, remoteURL)
    }
    
    /// Verifies if the media file is locally present and readable.
    public func isFileAvailable(relativePath: String) -> Bool {
        return resolveURL(for: relativePath) != nil
    }
    
    /// Verifies if an entire course (all sessions + intro video) is downloaded and available offline.
    public func isCourseAvailable(course: CatalogCourse) -> Bool {
        if let intro = course.introVideo, !isFileAvailable(relativePath: intro.relativePath) {
            return false
        }
        for session in course.sessions {
            if !isFileAvailable(relativePath: session.relativePath) {
                return false
            }
            for video in session.videoAttachments ?? [] {
                if !isFileAvailable(relativePath: video.relativePath) {
                    return false
                }
            }
        }
        return true
    }
    
    /// Counts found tracks vs total tracks in a course.
    public func courseAvailableTrackCount(course: CatalogCourse) -> (found: Int, total: Int) {
        var found = 0
        var total = 0
        
        if let intro = course.introVideo {
            total += 1
            if isFileAvailable(relativePath: intro.relativePath) { found += 1 }
        }
        
        for session in course.sessions {
            total += 1
            if isFileAvailable(relativePath: session.relativePath) { found += 1 }
            for video in session.videoAttachments ?? [] {
                total += 1
                if isFileAvailable(relativePath: video.relativePath) { found += 1 }
            }
        }
        
        return (found, total)
    }
    
    /// Calculates total storage size of all tracks in a course.
    public func courseTotalSizeBytes(course: CatalogCourse) -> Int64 {
        var total: Int64 = 0
        if let intro = course.introVideo {
            total += intro.sizeBytes
        }
        for session in course.sessions {
            total += session.sizeBytes
            for video in session.videoAttachments ?? [] {
                total += video.sizeBytes
            }
        }
        return total
    }

    
    /// Checks whether the library directory is correctly hardened with iCloud backup exclusion and complete-until-auth protection.
    public func checkHardeningStatus() -> Bool {
        let url = libraryDirectoryURL
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }
        
        var isExcludedFromBackup = false
        if let values = try? url.resourceValues(forKeys: [.isExcludedFromBackupKey]),
           let excluded = values.isExcludedFromBackup {
            isExcludedFromBackup = excluded
        }
        
        var isProtected = false
        if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
           let protection = attributes[.protectionKey] as? FileProtectionType {
            isProtected = (protection == .completeUntilFirstUserAuthentication)
        }
        
        return isExcludedFromBackup && isProtected
    }
    
    /// Hardens the library folder with iCloud backup exclusion and background read permissions.
    @discardableResult
    public func applyHardeningAndProtection() -> Bool {
        let url = libraryDirectoryURL
        let fileManager = FileManager.default
        
        do {
            if !fileManager.fileExists(atPath: url.path) {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            }
            
            // 1. Exclude from iCloud backup
            var mutableURL = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try mutableURL.setResourceValues(values)
            
            // 2. Set NSFileProtectionCompleteUntilFirstUserAuthentication
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            return checkHardeningStatus()
        } catch {
            return false
        }
    }
    
    /// Computes total storage size currently occupied by Documents/MindSpaceLibrary/
    public func getLibraryStorageSizeBytes() -> Int64 {
        let url = libraryDirectoryURL
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
    
    /// Asynchronously performs real scan of every media path defined in the catalog manifest.
    /// Checks existence, file size, and optionally SHA-256 checksums.
    public func verifyAllCatalogEntries(
        manifest: CatalogManifest?,
        validateChecksums: Bool = false
    ) async -> LibraryVerificationReport {
        let isHardened = checkHardeningStatus()
        
        guard let manifest = manifest else {
            return LibraryVerificationReport(
                totalTracks: 0,
                foundCount: 0,
                missingCount: 0,
                sizeMismatchedCount: 0,
                checksumMismatchedCount: 0,
                missingPaths: [],
                totalHoursFormatted: "0.0 hrs",
                isHardened: isHardened,
                verifiedAt: Date()
            )
        }
        
        var totalCount = 0
        var foundCount = 0
        var missingCount = 0
        var sizeMismatchCount = 0
        var checksumMismatchCount = 0
        var missingList: [String] = []
        
        // Collect all catalog items
        struct MediaCheckItem {
            let relativePath: String
            let expectedSizeBytes: Int64
            let expectedSHA256: String
        }
        
        var items: [MediaCheckItem] = []
        
        for category in manifest.categories {
            for course in category.courses {
                if let intro = course.introVideo {
                    items.append(MediaCheckItem(
                        relativePath: intro.relativePath,
                        expectedSizeBytes: intro.sizeBytes,
                        expectedSHA256: intro.sha256
                    ))
                }
                for session in course.sessions {
                    items.append(MediaCheckItem(
                        relativePath: session.relativePath,
                        expectedSizeBytes: session.sizeBytes,
                        expectedSHA256: session.sha256
                    ))
                    for video in session.videoAttachments ?? [] {
                        items.append(MediaCheckItem(
                            relativePath: video.relativePath,
                            expectedSizeBytes: video.sizeBytes,
                            expectedSHA256: video.sha256
                        ))
                    }
                }
            }
        }
        
        for singleCategory in manifest.singlesCategories {
            for session in singleCategory.sessions {
                items.append(MediaCheckItem(
                    relativePath: session.relativePath,
                    expectedSizeBytes: session.sizeBytes,
                    expectedSHA256: session.sha256
                ))
            }
        }

        totalCount = items.count

        for item in items {
            if Task.isCancelled { break }
            await Task.yield()
            guard let resolvedURL = resolveURL(for: item.relativePath) else {
                missingCount += 1
                missingList.append(item.relativePath)
                continue
            }
            
            foundCount += 1
            
            // Check file size if expected size > 0
            if item.expectedSizeBytes > 0 {
                if let attr = try? FileManager.default.attributesOfItem(atPath: resolvedURL.path),
                   let actualSize = attr[.size] as? Int64 {
                    if actualSize != item.expectedSizeBytes {
                        sizeMismatchCount += 1
                    }
                }
            }
            
            // Full SHA-256 Checksum validation if requested (streamed, constant memory)
            if validateChecksums && !item.expectedSHA256.isEmpty {
                if let hashString = Self.streamSHA256Hex(of: resolvedURL),
                   hashString.lowercased() == item.expectedSHA256.lowercased() {
                    // match
                } else {
                    checksumMismatchCount += 1
                }
            }
        }
        
        let hoursFormatted = String(format: "%.1f hrs", manifest.totalDurationHours)
        
        return LibraryVerificationReport(
            totalTracks: totalCount,
            foundCount: foundCount,
            missingCount: missingCount,
            sizeMismatchedCount: sizeMismatchCount,
            checksumMismatchedCount: checksumMismatchCount,
            missingPaths: missingList,
            totalHoursFormatted: hoursFormatted,
            isHardened: isHardened,
            verifiedAt: Date()
        )
    }

    /// Constant-memory SHA-256 used by both the audit and sync install paths.
    public static func streamSHA256Hex(of fileURL: URL, bufferSize: Int = 65536) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: bufferSize)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }
}
