import Testing
import Foundation

struct ZeroNetworkTests {
    
    @Test func testZeroNetworkAPIsReferencedInSource() throws {
        let forbiddenSymbols = ["URLSession", "WebKit", "CFNetwork", "Network.framework", "NWPathMonitor"]
        
        let currentDir = FileManager.default.currentDirectoryPath
        let sourcesURL = URL(fileURLWithPath: currentDir).appendingPathComponent("Sources")
        
        guard FileManager.default.fileExists(atPath: sourcesURL.path) else {
            // Test run inside bundle where Sources is not directly on disk
            return
        }
        
        guard let enumerator = FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return
        }
        
        var violations: [String] = []
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                for symbol in forbiddenSymbols {
                    if content.contains(symbol) {
                        violations.append("\(fileURL.lastPathComponent) contains forbidden networking symbol '\(symbol)'")
                    }
                }
            }
        }
        
        #expect(violations.isEmpty, "Zero-network violations detected: \(violations.joined(separator: ", "))")
    }
}
