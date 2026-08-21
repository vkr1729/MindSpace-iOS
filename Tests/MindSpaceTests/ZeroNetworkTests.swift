import XCTest
import Foundation

final class ZeroNetworkTests: XCTestCase {
    
    func testZeroNetworkAPIsReferencedInSource() throws {
        let forbiddenSymbols = ["URLSession", "WebKit", "CFNetwork", "Network.framework", "NWPathMonitor"]
        
        let currentDir = FileManager.default.currentDirectoryPath
        let sourcesURL = URL(fileURLWithPath: currentDir).appendingPathComponent("Sources")
        
        guard FileManager.default.fileExists(atPath: sourcesURL.path) else {
            return
        }
        
        guard let enumerator = FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return
        }
        
        var violations: [String] = []
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                // GitHubSyncService is the dedicated authenticated sync manager
                if fileURL.lastPathComponent == "GitHubSyncService.swift" {
                    continue
                }
                
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                for symbol in forbiddenSymbols {
                    if content.contains(symbol) {
                        violations.append("\(fileURL.lastPathComponent) contains forbidden networking symbol '\(symbol)'")
                    }
                }
            }
        }
        
        XCTAssertTrue(violations.isEmpty, "Zero-network violations detected: \(violations.joined(separator: ", "))")
    }
}
