import XCTest
@testable import ModelGraphGenerator

final class ParserIntegrationTests: XCTestCase {
    
    // MARK: - CodingKeysParser Tests
    
    func testCodingKeysParser_SimpleEnum() {
        let tempFile = createTempFile(content: """
        struct User: Codable {
            let firstName: String
            let lastName: String
            
            enum CodingKeys: String, CodingKey {
                case firstName = "first_name"
                case lastName = "last_name"
            }
        }
        """)
        
        let keys = CodingKeysParser.extractCodingKeys(from: tempFile, typeName: "User")
        
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(keys["firstName"], "first_name")
        XCTAssertEqual(keys["lastName"], "last_name")
    }
    
    func testCodingKeysParser_MixedMappings() {
        let tempFile = createTempFile(content: """
        struct Product: Codable {
            let id: String
            let name: String
            let price: Double
            
            enum CodingKeys: String, CodingKey {
                case id = "product_id"
                case name = "product_name"
                case price = "unit_price"
            }
        }
        """)
        
        let keys = CodingKeysParser.extractCodingKeys(from: tempFile, typeName: "Product")
        
        XCTAssertEqual(keys.count, 3)
        XCTAssertEqual(keys["id"], "product_id")
        XCTAssertEqual(keys["name"], "product_name")
        XCTAssertEqual(keys["price"], "unit_price")
    }
    
    func testCodingKeysParser_Extension() {
        let tempFile = createTempFile(content: """
        struct Order: Codable {
            let orderId: String
        }
        
        extension Order {
            enum CodingKeys: String, CodingKey {
                case orderId = "order_id"
            }
        }
        """)
        
        let keys = CodingKeysParser.extractCodingKeys(from: tempFile, typeName: "Order")
        
        XCTAssertEqual(keys.count, 1)
        XCTAssertEqual(keys["orderId"], "order_id")
    }
    
    func testCodingKeysParser_NoEnum() {
        let tempFile = createTempFile(content: """
        struct Simple: Codable {
            let name: String
        }
        """)
        
        let keys = CodingKeysParser.extractCodingKeys(from: tempFile, typeName: "Simple")
        
        XCTAssertTrue(keys.isEmpty)
    }
    
    // MARK: - PolymorphicParser Tests
    
    func testPolymorphicParser_BasicMapping() {
        let tempFile = createTempFile(content: """
        struct Container {
            @PolymorphicMapping(discriminator: "type", variants: ["dog": Dog.self, "cat": Cat.self])
            let animal: Animal
        }
        """)
        
        let mapping = PolymorphicParser.extractPolymorphicMapping(
            from: tempFile,
            typeName: "Container",
            propertyName: "animal"
        )
        
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.discriminatorKey, "type")
        XCTAssertEqual(mapping?.variants.count, 2)
        XCTAssertEqual(mapping?.variants["dog"], "Dog")
        XCTAssertEqual(mapping?.variants["cat"], "Cat")
    }
    
    func testPolymorphicParser_MultipleVariants() {
        let tempFile = createTempFile(content: """
        struct Zoo {
            @PolymorphicMapping(discriminator: "animal_type", variants: [
                "dog": Dog.self, 
                "cat": Cat.self, 
                "bird": Bird.self
            ])
            let animals: [Animal]
        }
        """)
        
        let mapping = PolymorphicParser.extractPolymorphicMapping(
            from: tempFile,
            typeName: "Zoo",
            propertyName: "animals"
        )
        
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.discriminatorKey, "animal_type")
        XCTAssertEqual(mapping?.variants.count, 3)
        XCTAssertEqual(mapping?.variants["bird"], "Bird")
    }
    
    func testPolymorphicParser_NoAnnotation() {
        let tempFile = createTempFile(content: """
        struct Container {
            let animal: Animal
        }
        """)
        
        let mapping = PolymorphicParser.extractPolymorphicMapping(
            from: tempFile,
            typeName: "Container",
            propertyName: "animal"
        )
        
        XCTAssertNil(mapping)
    }
    
    func testPolymorphicParser_WrongProperty() {
        let tempFile = createTempFile(content: """
        struct Container {
            @PolymorphicMapping(discriminator: "type", variants: ["dog": Dog.self])
            let animal: Animal
            let other: String
        }
        """)
        
        let mapping = PolymorphicParser.extractPolymorphicMapping(
            from: tempFile,
            typeName: "Container",
            propertyName: "other"
        )
        
        XCTAssertNil(mapping)
    }
    
    // MARK: - KnotParser Tests
    
    func testKnotParser_MultiKnot() {
        let tempFile = createTempFile(content: """
        @ChimeraMultiKnot(schemaId = "FeatureConfig", subSchemas = [Config1.class, Config2.class])
        struct FeatureConfig {
            let setting: String
        }
        """)
        
        let knotInfo = KnotParser.extractKnotAnnotation(from: tempFile, typeName: "FeatureConfig")
        
        XCTAssertNotNil(knotInfo)
        XCTAssertEqual(knotInfo?.schemaId, "FeatureConfig")
        XCTAssertEqual(knotInfo?.knotType, .multiKnot)
        XCTAssertEqual(knotInfo?.subSchemas.count, 2)
        XCTAssertTrue(knotInfo?.subSchemas.contains("Config1") ?? false)
        XCTAssertTrue(knotInfo?.subSchemas.contains("Config2") ?? false)
    }
    
    func testKnotParser_MapKnot() {
        let tempFile = createTempFile(content: """
        @ChimeraMapKnot(schemaId = "FeatureMap", subSchemas = [MapConfig1.class, MapConfig2.class])
        struct FeatureMap {
            let settings: [String: String]
        }
        """)
        
        let knotInfo = KnotParser.extractKnotAnnotation(from: tempFile, typeName: "FeatureMap")
        
        XCTAssertNotNil(knotInfo)
        XCTAssertEqual(knotInfo?.schemaId, "FeatureMap")
        XCTAssertEqual(knotInfo?.knotType, .mapKnot)
        XCTAssertEqual(knotInfo?.subSchemas.count, 2)
    }
    
    func testKnotParser_EmptySubSchemas() {
        let tempFile = createTempFile(content: """
        @ChimeraMultiKnot(schemaId = "SimpleKnot", subSchemas = [])
        struct SimpleKnot {
            let value: String
        }
        """)
        
        let knotInfo = KnotParser.extractKnotAnnotation(from: tempFile, typeName: "SimpleKnot")
        
        XCTAssertNotNil(knotInfo)
        XCTAssertEqual(knotInfo?.schemaId, "SimpleKnot")
        XCTAssertTrue(knotInfo?.subSchemas.isEmpty ?? false)
    }
    
    func testKnotParser_NoAnnotation() {
        let tempFile = createTempFile(content: """
        struct RegularStruct {
            let value: String
        }
        """)
        
        let knotInfo = KnotParser.extractKnotAnnotation(from: tempFile, typeName: "RegularStruct")
        
        XCTAssertNil(knotInfo)
    }
    
    func testKnotParser_WrongType() {
        let tempFile = createTempFile(content: """
        @ChimeraMultiKnot(schemaId = "Config", subSchemas = [])
        struct Config {
            let value: String
        }
        """)
        
        let knotInfo = KnotParser.extractKnotAnnotation(from: tempFile, typeName: "WrongType")
        
        XCTAssertNil(knotInfo)
    }
    
    // MARK: - Cross-Parser Tests
    
    func testMultipleAnnotations_ComplexStruct() {
        let tempFile = createTempFile(content: """
        @ChimeraMultiKnot(schemaId = "AnimalContainer", subSchemas = [])
        struct AnimalContainer: Codable {
            @PolymorphicMapping(discriminator: "type", variants: ["dog": Dog.self, "cat": Cat.self])
            let animal: Animal
            
            let containerId: String
            
            enum CodingKeys: String, CodingKey {
                case animal = "animal_data"
                case containerId = "container_id"
            }
        }
        """)
        
        // Test knot annotation
        let knotInfo = KnotParser.extractKnotAnnotation(from: tempFile, typeName: "AnimalContainer")
        XCTAssertNotNil(knotInfo)
        XCTAssertEqual(knotInfo?.schemaId, "AnimalContainer")
        
        // Test polymorphic mapping
        let polymorphic = PolymorphicParser.extractPolymorphicMapping(
            from: tempFile,
            typeName: "AnimalContainer",
            propertyName: "animal"
        )
        XCTAssertNotNil(polymorphic)
        XCTAssertEqual(polymorphic?.discriminatorKey, "type")
        
        // Test CodingKeys
        let keys = CodingKeysParser.extractCodingKeys(from: tempFile,typeName: "AnimalContainer")
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(keys["animal"], "animal_data")
        XCTAssertEqual(keys["containerId"], "container_id")
    }
    
    // MARK: - Helper Methods
    
    private func createTempFile(content: String) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_\(UUID().uuidString).swift"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Clean up in test teardown
        addTeardownBlock {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        return fileURL.path
    }
}
