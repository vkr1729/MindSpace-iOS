import Foundation

/// Centralized resolver that turns relative media paths into absolute file URLs inside
/// Documents/MindSpaceLibrary/ with sandboxing and file-protection safeguards.
public struct LibraryPathResolver: Sendable {
    public static let shared = LibraryPathResolver()
    
    public let libraryFolderName = "MindSpaceLibrary"
    
    public init() {}
    
    /// Root directory URL for user-supplied media library in Documents/
    public var libraryDirectoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(libraryFolderName, isDirectory: true)
    }
    
    /// Resolves a relative path (e.g. "Packs/1 - Foundation/Basics/Day 01.mp3") to a local URL.
    /// Checks Documents/MindSpaceLibrary/ first, then Bundle.main as a fallback for testing.
    public func resolveURL(for relativePath: String) -> URL? {
        let fileURL = libraryDirectoryURL.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        // Check main bundle (useful for testing or previews)
        if let bundleURL = Bundle.main.url(forResource: relativePath, withExtension: nil) {
            return bundleURL
        }
        
        return fileURL // Return destination URL even if not yet transferred
    }
    
    /// Verifies if the media file is locally present and readable.
    public func isFileAvailable(relativePath: String) -> Bool {
        let fileURL = libraryDirectoryURL.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: fileURL.path)
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
}
