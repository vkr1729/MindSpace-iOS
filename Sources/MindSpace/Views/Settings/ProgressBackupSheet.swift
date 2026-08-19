import SwiftUI
import SwiftData

#if os(iOS)
import UIKit

/// UIActivityViewController wrapper for exporting .mindspace files to Files, AirDrop, etc.
public struct ShareSheetView: UIViewControllerRepresentable {
    public let items: [Any]
    
    public init(items: [Any]) {
        self.items = items
    }
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// UIDocumentPickerViewController wrapper for importing .mindspace files.
public struct DocumentPickerView: UIViewControllerRepresentable {
    public let onDocumentPicked: (URL) -> Void
    
    public init(onDocumentPicked: @escaping (URL) -> Void) {
        self.onDocumentPicked = onDocumentPicked
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .data], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }
    
    public final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void
        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentPicked(url)
        }
    }
}
#endif

/// Preview dialog presented when the user selects a `.mindspace` file to import.
public struct ImportPreviewDialogView: View {
    public let document: MindSpaceBackupDocument
    public let onMerge: () -> Void
    public let onCleanRestore: () -> Void
    public let onCancel: () -> Void
    
    public init(
        document: MindSpaceBackupDocument,
        onMerge: @escaping () -> Void,
        onCleanRestore: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.document = document
        self.onMerge = onMerge
        self.onCleanRestore = onCleanRestore
        self.onCancel = onCancel
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Import Progress")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(CosmosTheme.textPrimary)
            
            Text("MindSpace backup detected (\(document.exportedAt.prefix(10)))")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(CosmosTheme.textSecondary)
            
            CosmicCard(padding: 16) {
                VStack(spacing: 10) {
                    HStack {
                        Text("Completed Sessions")
                            .foregroundColor(CosmosTheme.textSecondary)
                        Spacer()
                        Text("\(document.completionEvents.count)")
                            .foregroundColor(CosmosTheme.textPrimary)
                            .bold()
                    }
                    HStack {
                        Text("Current Streak")
                            .foregroundColor(CosmosTheme.textSecondary)
                        Spacer()
                        Text("\(document.stats.currentStreak) days")
                            .foregroundColor(CosmosTheme.starlightGold)
                            .bold()
                    }
                    HStack {
                        Text("Mindful Minutes")
                            .foregroundColor(CosmosTheme.textSecondary)
                        Spacer()
                        Text("\(document.stats.totalMindfulMinutes) min")
                            .foregroundColor(CosmosTheme.cosmicPurple)
                            .bold()
                    }
                }
                .font(.system(size: 14, design: .rounded))
            }
            
            VStack(spacing: 10) {
                Button(action: onMerge) {
                    Text("Merge with Existing Progress")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CosmosTheme.cosmicPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                
                Button(action: onCleanRestore) {
                    Text("Restore Clean (Replace)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(CosmosTheme.solarCoral)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(CosmosTheme.solarCoral.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(CosmosTheme.spaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(24)
    }
}
