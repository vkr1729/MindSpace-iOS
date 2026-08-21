import XCTest
import SwiftUI
@testable import MindSpace

final class CelestialVisualTests: XCTestCase {
    
    // MARK: - PlanetStyle Asset Name Integrity
    func testPlanetStyleAssetNames() {
        for style in PlanetStyle.allCases {
            XCTAssertFalse(style.assetImageName.isEmpty, "Asset image name must not be empty for \(style)")
            XCTAssertFalse(style.rawValue.isEmpty, "Raw value must not be empty for \(style)")
        }
        
        XCTAssertEqual(PlanetStyle.purpleRinged.assetImageName, "planet_foundation")
        XCTAssertEqual(PlanetStyle.auroraTeal.assetImageName, "planet_health")
        XCTAssertEqual(PlanetStyle.solarCoral.assetImageName, "planet_happiness")
        XCTAssertEqual(PlanetStyle.electricBlue.assetImageName, "planet_work")
        XCTAssertEqual(PlanetStyle.crescentMoon.assetImageName, "planet_sleep")
        XCTAssertEqual(PlanetStyle.deepLavender.assetImageName, "planet_students")
        XCTAssertEqual(PlanetStyle.brave.assetImageName, "planet_brave")
        XCTAssertEqual(PlanetStyle.sport.assetImageName, "planet_sport")
        XCTAssertEqual(PlanetStyle.goldenSun.assetImageName, "planet_pro")
        XCTAssertEqual(PlanetStyle.pro.assetImageName, "planet_pro")
    }
    
    // MARK: - Planet Primary & Secondary Color Mappings
    func testPlanetColorMappings() {
        for style in PlanetStyle.allCases {
            let primary = style.primaryColor
            let secondary = style.secondaryColor
            XCTAssertNotNil(primary)
            XCTAssertNotNil(secondary)
        }
        
        XCTAssertEqual(PlanetStyle.purpleRinged.primaryColor, CosmosTheme.cosmicPurple)
        XCTAssertEqual(PlanetStyle.auroraTeal.primaryColor, CosmosTheme.auroraTeal)
        XCTAssertEqual(PlanetStyle.solarCoral.primaryColor, CosmosTheme.solarCoral)
        XCTAssertEqual(PlanetStyle.electricBlue.primaryColor, CosmosTheme.celestialBlue)
        XCTAssertEqual(PlanetStyle.crescentMoon.primaryColor, CosmosTheme.moonLavender)
        XCTAssertEqual(PlanetStyle.goldenSun.primaryColor, CosmosTheme.starlightGold)
    }
    
    // MARK: - CelestialPlanetView Multi-Scale Initialization
    func testCelestialPlanetViewInitialization() {
        let testScales: [CGFloat] = [36, 44, 48, 52, 68, 74, 90, 140, 160, 280]
        
        for style in PlanetStyle.allCases {
            for size in testScales {
                let view = CelestialPlanetView(
                    style: style,
                    size: size,
                    hasRings: style == .purpleRinged,
                    isAnimated: false
                )
                XCTAssertEqual(view.style, style)
                XCTAssertEqual(view.size, size)
            }
        }
    }
    
    // MARK: - Typealias Backward Compatibility
    func testCelestialPlanetStyleTypealias() {
        let aliasStyle: CelestialPlanetStyle = .purpleRinged
        XCTAssertEqual(aliasStyle, PlanetStyle.purpleRinged)
    }
}
