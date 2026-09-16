import Foundation
import SwiftData

public enum SettingsStore {
    @MainActor
    public static func fetchOrCreate(in modelContext: ModelContext) -> UserSettings {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                return existing
            }
        } catch {
            modelContext.rollback()
        }
        let created = UserSettings()
        modelContext.insert(created)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            var refetch = FetchDescriptor<UserSettings>()
            refetch.fetchLimit = 1
            if let raced = try? modelContext.fetch(refetch).first {
                return raced
            }
        }
        return created
    }
}
