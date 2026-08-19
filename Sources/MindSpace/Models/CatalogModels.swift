import Foundation

// MARK: - Root Catalog Manifest
public struct CatalogManifest: Codable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: String
    public let totalFiles: Int
    public let totalDuration: Double
    public let totalDurationHours: Double
    public let totalSizeBytes: Int64
    public let categories: [CatalogCategory]
    public let singlesCategories: [SinglesCategory]
    
    public init(
        schemaVersion: Int,
        generatedAt: String,
        totalFiles: Int,
        totalDuration: Double,
        totalDurationHours: Double,
        totalSizeBytes: Int64,
        categories: [CatalogCategory],
        singlesCategories: [SinglesCategory]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.totalFiles = totalFiles
        self.totalDuration = totalDuration
        self.totalDurationHours = totalDurationHours
        self.totalSizeBytes = totalSizeBytes
        self.categories = categories
        self.singlesCategories = singlesCategories
    }
}

// MARK: - Pack Category (8 Top-Level Categories)
public struct CatalogCategory: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let type: String
    public let name: String
    public let folderName: String
    public let order: Int
    public let description: String
    public let colorHex: String
    public let iconName: String
    public let courses: [CatalogCourse]
    
    public init(
        id: String,
        type: String,
        name: String,
        folderName: String,
        order: Int,
        description: String,
        colorHex: String,
        iconName: String,
        courses: [CatalogCourse]
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.folderName = folderName
        self.order = order
        self.description = description
        self.colorHex = colorHex
        self.iconName = iconName
        self.courses = courses
    }
}

// MARK: - Course / Pack Level (44 Total Courses)
public struct CatalogCourse: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let folderName: String
    public let order: Int
    public let description: String
    public let totalSessions: Int
    public let hasGapWaiver: Bool
    public let introVideo: VideoAttachment?
    public let sessions: [CatalogSession]
    
    public init(
        id: String,
        name: String,
        folderName: String,
        order: Int,
        description: String,
        totalSessions: Int,
        hasGapWaiver: Bool,
        introVideo: VideoAttachment?,
        sessions: [CatalogSession]
    ) {
        self.id = id
        self.name = name
        self.folderName = folderName
        self.order = order
        self.description = description
        self.totalSessions = totalSessions
        self.hasGapWaiver = hasGapWaiver
        self.introVideo = introVideo
        self.sessions = sessions
    }
}

// MARK: - Catalog Session (Pack Daily Session)
public struct CatalogSession: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let dayNumber: Int
    public let relativePath: String
    public let duration: Double
    public let sizeBytes: Int64
    public let sha256: String
    public let codec: String
    public let videoAttachments: [VideoAttachment]?
    
    public init(
        id: String,
        title: String,
        dayNumber: Int,
        relativePath: String,
        duration: Double,
        sizeBytes: Int64,
        sha256: String,
        codec: String,
        videoAttachments: [VideoAttachment]?
    ) {
        self.id = id
        self.title = title
        self.dayNumber = dayNumber
        self.relativePath = relativePath
        self.duration = duration
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.codec = codec
        self.videoAttachments = videoAttachments
    }
    
    public var formattedDuration: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Video Attachment
public struct VideoAttachment: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let relativePath: String
    public let duration: Double
    public let sizeBytes: Int64
    public let sha256: String
    public let width: Int?
    public let height: Int?
    public let codec: String
    public let placement: String? // "beforeSession" or nil for intro
    
    public init(
        id: String,
        title: String,
        relativePath: String,
        duration: Double,
        sizeBytes: Int64,
        sha256: String,
        width: Int?,
        height: Int?,
        codec: String,
        placement: String? = nil
    ) {
        self.id = id
        self.title = title
        self.relativePath = relativePath
        self.duration = duration
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.width = width
        self.height = height
        self.codec = codec
        self.placement = placement
    }
}

// MARK: - Singles Category (15 Standalone Categories)
public struct SinglesCategory: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let folderName: String
    public let order: Int
    public let description: String
    public let colorHex: String
    public let iconName: String
    public let sessions: [SingleSession]
    
    public init(
        id: String,
        name: String,
        folderName: String,
        order: Int,
        description: String,
        colorHex: String,
        iconName: String,
        sessions: [SingleSession]
    ) {
        self.id = id
        self.name = name
        self.folderName = folderName
        self.order = order
        self.description = description
        self.colorHex = colorHex
        self.iconName = iconName
        self.sessions = sessions
    }
}

// MARK: - Single Standalone Session
public struct SingleSession: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let category: String
    public let subCategory: String?
    public let relativePath: String
    public let duration: Double
    public let sizeBytes: Int64
    public let sha256: String
    public let codec: String
    
    public init(
        id: String,
        title: String,
        category: String,
        subCategory: String?,
        relativePath: String,
        duration: Double,
        sizeBytes: Int64,
        sha256: String,
        codec: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.subCategory = subCategory
        self.relativePath = relativePath
        self.duration = duration
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.codec = codec
    }
    
    public var formattedDuration: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
