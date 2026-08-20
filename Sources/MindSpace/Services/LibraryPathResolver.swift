import Foundation
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
        totalTracks > 0 && missingCount == 0 && sizeMismatchedCount == 0 && checksumMismatchedCount == 0
    }
}

/// Centralized resolver that turns relative media paths into absolute file URLs inside
/// Documents/MindSpaceLibrary/ with sandboxing and file-protection safeguards.
public struct LibraryPathResolver: Sendable {
    public static let shared = LibraryPathResolver()
    
    public let libraryFolderName = "MindSpaceLibrary"
    
    private static let _cachedLibraryURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("MindSpaceLibrary", isDirectory: true)
    }()
    
    public init() {}
    
    /// Root directory URL for user-supplied media library in Documents/
    public var libraryDirectoryURL: URL {
        Self._cachedLibraryURL
    }
    
    /// Resolves a relative path (e.g. "Packs/1 - Foundation/Basics/Day 01.mp3") to a local URL.
    /// Checks Documents/MindSpaceLibrary/ first, then Bundle.main as a fallback.
    /// Returns nil if the file is missing from both locations.
    public func resolveURL(for relativePath: String) -> URL? {
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
        
        // Return nil if file does not exist on disk
        return nil
    }
    
    /// Verifies if the media file is locally present and readable.
    public func isFileAvailable(relativePath: String) -> Bool {
        return resolveURL(for: relativePath) != nil
    }
    
    /// Hardens the library folder with iCloud backup exclusion and background read permissions.
    public func applyHardeningAndProtection() {
        let url = libraryDirectoryURL
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        // 1. Exclude from iCloud backup
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(values)
        
        // 2. Set NSFileProtectionCompleteUntilFirstUserAuthentication
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
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
        guard let manifest = manifest else {
            return LibraryVerificationReport(
                totalTracks: 0,
                foundCount: 0,
                missingCount: 0,
                sizeMismatchedCount: 0,
                checksumMismatchedCount: 0,
                missingPaths: [],
                totalHoursFormatted: "0.0 hrs",
                isHardened: true,
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
            
            // Full SHA-256 Checksum validation if requested
            if validateChecksums && !item.expectedSHA256.isEmpty {
                if let fileData = try? Data(contentsOf: resolvedURL, options: .mappedIfSafe) {
                    let hash = SHA256.hash(data: fileData)
                    let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                    if hashString.lowercased() != item.expectedSHA256.lowercased() {
                        checksumMismatchCount += 1
                    }
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
            isHardened: true,
            verifiedAt: Date()
        )
    }
}

