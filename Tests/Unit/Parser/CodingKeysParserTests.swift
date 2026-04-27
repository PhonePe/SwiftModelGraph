import XCTest
@testable import ModelGraphGenerator

final class CodingKeysParserTests: XCTestCase {
    
    // MARK: - Test Files Setup
    
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create a temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temporary files
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    func createTestFile(name: String, content: String) -> String {
        let fileURL = tempDirectory.appendingPathComponent(name)
        try! content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL.path
    }
    
    // MARK: - Basic CodingKeys Tests
    
    func testSimpleCodingKeysMapping() {
        let swiftCode = """
        struct User: Codable {
            let id: String
            let name: String
            
            enum CodingKeys: String, CodingKey {
                case id
                case name = "full_name"
            }
        }
        """
        
        let filePath = createTestFile(name: "User.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "User")
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result["name"], "full_name")
    }
    
    func testCodingKeysWithAllMappings() {
        let swiftCode = """
        struct Product: Codable {
            let productId: String
            let productName: String
            let price: Double
            
            enum CodingKeys: String, CodingKey {
                case productId = "product_id"
                case productName = "product_name"
                case price = "unit_price"
            }
        }
        """
        
        let filePath = createTestFile(name: "Product.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Product")
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result["productId"], "product_id")
        XCTAssertEqual(result["productName"], "product_name")
        XCTAssertEqual(result["price"], "unit_price")
    }
    
    func testCodingKeysWithNoMappings() {
        let swiftCode = """
        struct SimpleModel: Codable {
            let id: String
            let value: Int
            
            enum CodingKeys: String, CodingKey {
                case id
                case value
            }
        }
        """
        
        let filePath = createTestFile(name: "SimpleModel.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "SimpleModel")
        
        // Parser only returns explicitly mapped keys
        XCTAssertEqual(result.count, 0)
    }
    
    // MARK: - Extension Tests
    
    func testCodingKeysInExtension() {
        let swiftCode = """
        struct Order {
            let orderId: String
            let total: Double
        }
        
        extension Order: Codable {
            enum CodingKeys: String, CodingKey {
                case orderId = "order_id"
                case total = "total_amount"
            }
        }
        """
        
        let filePath = createTestFile(name: "Order.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Order")
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["orderId"], "order_id")
        XCTAssertEqual(result["total"], "total_amount")
    }
    
    func testCodingKeysInMultipleExtensions() {
        let swiftCode = """
        struct Customer {
            let id: String
        }
        
        extension Customer {
            enum CodingKeys: String, CodingKey {
                case id = "customer_id"
                case name
            }
        }
        
        extension Customer {
            enum NestedKeys: String, CodingKey {
                case someOtherKey
            }
        }
        """
        
        let filePath = createTestFile(name: "Customer.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Customer")
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result["id"], "customer_id")
    }
    
    // MARK: - Class Tests
    
    func testCodingKeysInClass() {
        let swiftCode = """
        class Person: Codable {
            let firstName: String
            let lastName: String
            
            enum CodingKeys: String, CodingKey {
                case firstName = "first_name"
                case lastName = "last_name"
            }
        }
        """
        
        let filePath = createTestFile(name: "Person.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Person")
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["firstName"], "first_name")
        XCTAssertEqual(result["lastName"], "last_name")
    }
    
    // MARK: - Edge Cases
    
    func testNoCodingKeys() {
        let swiftCode = """
        struct NoKeys: Codable {
            let id: String
            let value: Int
        }
        """
        
        let filePath = createTestFile(name: "NoKeys.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "NoKeys")
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testNonCodingKeyEnum() {
        let swiftCode = """
        struct WithEnum {
            let status: Status
            
            enum Status: String {
                case active
                case inactive
            }
        }
        """
        
        let filePath = createTestFile(name: "WithEnum.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "WithEnum")
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testNestedTypeDoesNotInterfere() {
        let swiftCode = """
        struct Outer: Codable {
            let value: String
            
            enum CodingKeys: String, CodingKey {
                case value = "outer_value"
            }
            
            struct Inner: Codable {
                let innerValue: String
                
                enum CodingKeys: String, CodingKey {
                    case innerValue = "inner_value"
                }
            }
        }
        """
        
        let filePath = createTestFile(name: "Nested.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Outer")
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result["value"], "outer_value")
        XCTAssertNil(result["innerValue"])
    }
    
    func testWrongTypeNameReturnsEmpty() {
        let swiftCode = """
        struct ActualType: Codable {
            let id: String
            
            enum CodingKeys: String, CodingKey {
                case id = "actual_id"
            }
        }
        """
        
        let filePath = createTestFile(name: "Type.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "WrongType")
        
        XCTAssertEqual(result.count, 0)
    }
    
    func testInvalidFilePathReturnsEmpty() {
        let result = CodingKeysParser.extractCodingKeys(from: "/nonexistent/file.swift", typeName: "SomeType")
        XCTAssertEqual(result.count, 0)
    }
    
    // MARK: - Complex Scenarios
    
    func testMixedCodingKeysWithSomeExplicitMappings() {
        let swiftCode = """
        struct MixedMapping: Codable {
            let id: String
            let userName: String
            let email: String
            let age: Int
            
            enum CodingKeys: String, CodingKey {
                case id
                case userName = "user_name"
                case email
                case age = "user_age"
            }
        }
        """
        
        let filePath = createTestFile(name: "MixedMapping.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "MixedMapping")
        
        // Parser only returns explicitly mapped keys
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["userName"], "user_name")
        XCTAssertEqual(result["age"], "user_age")
    }
    
    func testCodingKeysWithSpecialCharacters() {
        let swiftCode = """
        struct SpecialChars: Codable {
            let userId: String
            let apiKey: String
            
            enum CodingKeys: String, CodingKey {
                case userId = "user-id"
                case apiKey = "api_key.secret"
            }
        }
        """
        
        let filePath = createTestFile(name: "SpecialChars.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "SpecialChars")
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["userId"], "user-id")
        XCTAssertEqual(result["apiKey"], "api_key.secret")
    }
    
    func testCodingKeysWithCodingKeyProtocolOnly() {
        let swiftCode = """
        struct TypeWithCodingKeyOnly: Codable {
            let value: String
            
            enum CodingKeys: CodingKey {
                case value
            }
        }
        """
        
        let filePath = createTestFile(name: "CodingKeyOnly.swift", content: swiftCode)
        let result = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "TypeWithCodingKeyOnly")
        
        // Parser only returns explicitly mapped keys (none in this case)
        XCTAssertEqual(result.count, 0)
    }
}
