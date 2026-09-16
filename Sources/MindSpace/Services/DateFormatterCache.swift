import Foundation

/// Centralized, high-performance thread-safe DateFormatter cache to eliminate repeated DateFormatter allocations.
/// Allocating DateFormatter is computationally expensive on Apple platforms; caching these formatters
/// prevents CPU spikes, main-thread hitches, and battery drain during frequent renders.
/// @unchecked Sendable because all formatter access is serialized through NSLock.
public final class DateFormatterCache: @unchecked Sendable {
    public static let shared = DateFormatterCache()
    
    private let lock = NSLock()
    
    // Calendar Day Key: "yyyy-MM-dd"
    private lazy var _dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
    
    // Month Year Display: "MMMM yyyy"
    private lazy var _monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = .current
        formatter.timeZone = .current
        return formatter
    }()
    
    // 24-Hour Time Key: "HH:mm"
    private lazy var _timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
    
    // Backup File Timestamp: "yyyy-MM-dd-HHmmss"
    private lazy var _backupFileTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
    
    // ISO8601 Date Formatter
    private lazy var _iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    private init() {}
    
    public static func dayKey(from date: Date, timeZoneIdentifier: String? = nil) -> String {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        if let tzId = timeZoneIdentifier, let tz = TimeZone(identifier: tzId) {
            let previousTz = shared._dayFormatter.timeZone
            shared._dayFormatter.timeZone = tz
            let result = shared._dayFormatter.string(from: date)
            shared._dayFormatter.timeZone = previousTz
            return result
        }
        return shared._dayFormatter.string(from: date)
    }
    
    public static func dateFromDayKey(_ key: String) -> Date? {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared._dayFormatter.date(from: key)
    }
    
    public static func monthYearString(from date: Date) -> String {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared._monthYearFormatter.string(from: date)
    }
    
    public static func timeString(from date: Date) -> String {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared._timeFormatter.string(from: date)
    }
    
    public static func backupTimestampString(from date: Date = Date()) -> String {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared._backupFileTimestampFormatter.string(from: date)
    }
    
    public static func iso8601String(from date: Date = Date()) -> String {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared._iso8601Formatter.string(from: date)
    }
    
    public static func dateFromISO8601(_ string: String) -> Date? {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared._iso8601Formatter.date(from: string)
    }
}
