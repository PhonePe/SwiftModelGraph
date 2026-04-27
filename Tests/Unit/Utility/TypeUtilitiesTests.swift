import XCTest
@testable import ModelGraphGenerator

final class TypeUtilitiesTests: XCTestCase {
    
    // MARK: - isPrimitiveType Tests
    
    func testIsPrimitiveType_SwiftIntegers() {
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Int"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Int8"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Int16"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Int32"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Int64"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("UInt"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("UInt8"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("UInt16"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("UInt32"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("UInt64"))
    }
    
    func testIsPrimitiveType_SwiftFloatingPoint() {
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Float"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Double"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Float16"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Float80"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("CGFloat"))
    }
    
    func testIsPrimitiveType_SwiftBasicTypes() {
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Bool"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("String"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Character"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Substring"))
    }
    
    func testIsPrimitiveType_SwiftSpecialTypes() {
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Void"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Never"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Any"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("AnyObject"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("AnyHashable"))
    }
    
    func testIsPrimitiveType_FoundationTypes() {
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Date"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Data"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("URL"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("UUID"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Decimal"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("NSNumber"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("NSString"))
    }
    
    func testIsPrimitiveType_TimeTypes() {
        XCTAssertTrue(TypeUtilities.isPrimitiveType("TimeInterval"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("DateInterval"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Locale"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Calendar"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("TimeZone"))
    }
    
    func testIsPrimitiveType_Collections() {
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Array"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Set"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Dictionary"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("Optional"))
    }
    
    func testIsPrimitiveType_CoreGraphicsTypes() {
        XCTAssertTrue(TypeUtilities.isPrimitiveType("CGPoint"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("CGSize"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("CGRect"))
    }
    
    func testIsPrimitiveType_ObjectiveCTypes() {
        XCTAssertTrue(TypeUtilities.isPrimitiveType("NSInteger"))
        XCTAssertTrue(TypeUtilities.isPrimitiveType("NSUInteger"))
    }
    
    func testIsPrimitiveType_CustomTypes_ReturnsFalse() {
        XCTAssertFalse(TypeUtilities.isPrimitiveType("User"))
        XCTAssertFalse(TypeUtilities.isPrimitiveType("MyCustomType"))
        XCTAssertFalse(TypeUtilities.isPrimitiveType("Address"))
        XCTAssertFalse(TypeUtilities.isPrimitiveType("Product"))
        XCTAssertFalse(TypeUtilities.isPrimitiveType("CustomModel"))
    }
    
    func testIsPrimitiveType_EmptyString_ReturnsFalse() {
        XCTAssertFalse(TypeUtilities.isPrimitiveType(""))
    }
    
    func testIsPrimitiveType_CaseSensitive() {
        // Should be case-sensitive
        XCTAssertTrue(TypeUtilities.isPrimitiveType("String"))
        XCTAssertFalse(TypeUtilities.isPrimitiveType("string"))
        XCTAssertFalse(TypeUtilities.isPrimitiveType("STRING"))
    }
    
    // MARK: - isSystemType Tests
    
    func testIsSystemType_FoundationPrefixes() {
        XCTAssertTrue(TypeUtilities.isSystemType("NSString"))
        XCTAssertTrue(TypeUtilities.isSystemType("NSArray"))
        XCTAssertTrue(TypeUtilities.isSystemType("NSDictionary"))
        XCTAssertTrue(TypeUtilities.isSystemType("NSObject"))
    }
    
    func testIsSystemType_UIKitPrefixes() {
        XCTAssertTrue(TypeUtilities.isSystemType("UIView"))
        XCTAssertTrue(TypeUtilities.isSystemType("UIViewController"))
        XCTAssertTrue(TypeUtilities.isSystemType("UIButton"))
        XCTAssertTrue(TypeUtilities.isSystemType("UILabel"))
    }
    
    func testIsSystemType_CoreGraphicsPrefixes() {
        XCTAssertTrue(TypeUtilities.isSystemType("CGContext"))
        XCTAssertTrue(TypeUtilities.isSystemType("CGPath"))
        XCTAssertTrue(TypeUtilities.isSystemType("CGImage"))
    }
    
    func testIsSystemType_CoreFoundationPrefixes() {
        XCTAssertTrue(TypeUtilities.isSystemType("CFString"))
        XCTAssertTrue(TypeUtilities.isSystemType("CFArray"))
        XCTAssertTrue(TypeUtilities.isSystemType("CFDictionary"))
    }
    
    func testIsSystemType_CoreAnimationPrefixes() {
        XCTAssertTrue(TypeUtilities.isSystemType("CALayer"))
        XCTAssertTrue(TypeUtilities.isSystemType("CAAnimation"))
    }
    
    func testIsSystemType_AVFoundationPrefixes() {
        XCTAssertTrue(TypeUtilities.isSystemType("AVPlayer"))
        XCTAssertTrue(TypeUtilities.isSystemType("AVAsset"))
    }
    
    func testIsSystemType_MapKitPrefixes() {
        XCTAssertTrue(TypeUtilities.isSystemType("MKMapView"))
        XCTAssertTrue(TypeUtilities.isSystemType("MKAnnotation"))
    }
    
    func testIsSystemType_SceneKitPrefixes() {
        XCTAssertTrue(TypeUtilities.isSystemType("SCNNode"))
        XCTAssertTrue(TypeUtilities.isSystemType("SCNScene"))
    }
    
    func testIsSystemType_SpriteKitPrefixes() {
        XCTAssertTrue(TypeUtilities.isSystemType("SKNode"))
        XCTAssertTrue(TypeUtilities.isSystemType("SKScene"))
    }
    
    func testIsSystemType_WebKitPrefixes() {
        XCTAssertTrue(TypeUtilities.isSystemType("WKWebView"))
        XCTAssertTrue(TypeUtilities.isSystemType("WKNavigationDelegate"))
    }
    
    func testIsSystemType_SwiftStandardProtocols() {
        XCTAssertTrue(TypeUtilities.isSystemType("Equatable"))
        XCTAssertTrue(TypeUtilities.isSystemType("Hashable"))
        XCTAssertTrue(TypeUtilities.isSystemType("Comparable"))
        XCTAssertTrue(TypeUtilities.isSystemType("Codable"))
        XCTAssertTrue(TypeUtilities.isSystemType("Encodable"))
        XCTAssertTrue(TypeUtilities.isSystemType("Decodable"))
    }
    
    func testIsSystemType_CustomStringConvertible() {
        XCTAssertTrue(TypeUtilities.isSystemType("CustomStringConvertible"))
        XCTAssertTrue(TypeUtilities.isSystemType("CustomDebugStringConvertible"))
    }
    
    func testIsSystemType_ErrorProtocols() {
        XCTAssertTrue(TypeUtilities.isSystemType("Error"))
        XCTAssertTrue(TypeUtilities.isSystemType("LocalizedError"))
    }
    
    func testIsSystemType_EnumProtocols() {
        XCTAssertTrue(TypeUtilities.isSystemType("RawRepresentable"))
        XCTAssertTrue(TypeUtilities.isSystemType("CaseIterable"))
    }
    
    func testIsSystemType_SwiftUIProtocols() {
        XCTAssertTrue(TypeUtilities.isSystemType("View"))
        XCTAssertTrue(TypeUtilities.isSystemType("ViewModifier"))
        XCTAssertTrue(TypeUtilities.isSystemType("Identifiable"))
        XCTAssertTrue(TypeUtilities.isSystemType("ObservableObject"))
    }
    
    func testIsSystemType_CustomTypes_ReturnsFalse() {
        XCTAssertFalse(TypeUtilities.isSystemType("User"))
        XCTAssertFalse(TypeUtilities.isSystemType("MyCustomType"))
        XCTAssertFalse(TypeUtilities.isSystemType("Address"))
        XCTAssertFalse(TypeUtilities.isSystemType("Product"))
    }
    
    func testIsSystemType_EmptyString_ReturnsFalse() {
        XCTAssertFalse(TypeUtilities.isSystemType(""))
    }
    
    func testIsSystemType_EdgeCases() {
        // Types that start with system prefixes but might be custom
        XCTAssertTrue(TypeUtilities.isSystemType("NSCustomType")) // Still considered system due to NS prefix
        XCTAssertTrue(TypeUtilities.isSystemType("UICustomView")) // Still considered system due to UI prefix
        
        // Types that don't match any pattern
        XCTAssertFalse(TypeUtilities.isSystemType("CustomNSType")) // NS not at start
        XCTAssertFalse(TypeUtilities.isSystemType("MyUIType")) // UI not at start
    }
    
    // MARK: - Integration Tests
    
    func testPrimitiveAndSystemType_Overlap() {
        // Some types might be both primitive and system types
        // Ensure consistent behavior
        let overlappingTypes = ["String", "Bool", "Int"]
        
        for type in overlappingTypes {
            let isPrimitive = TypeUtilities.isPrimitiveType(type)
            let isSystem = TypeUtilities.isSystemType(type)
            
            // Primitive Swift types should not be considered system types
            XCTAssertTrue(isPrimitive, "\(type) should be primitive")
            XCTAssertFalse(isSystem, "\(type) should not be system type")
        }
    }
    
    func testTypicalModelType_NotPrimitiveNorSystem() {
        let customTypes = ["User", "Product", "Address", "Order", "Cart"]
        
        for type in customTypes {
            XCTAssertFalse(TypeUtilities.isPrimitiveType(type), "\(type) should not be primitive")
            XCTAssertFalse(TypeUtilities.isSystemType(type), "\(type) should not be system type")
        }
    }
}
