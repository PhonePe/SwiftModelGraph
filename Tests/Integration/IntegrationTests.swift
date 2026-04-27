import XCTest
import Foundation
import SwiftParser
@testable import ModelGraphGenerator

final class IntegrationTests: XCTestCase {
    
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func createTestFile(name: String, content: String) -> String {
        let fileURL = tempDirectory.appendingPathComponent(name)
        try! content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL.path
    }
    
    // MARK: - End-to-End CodingKeys Parsing
    
    func testRealWorldCodingKeysExtraction() {
        let swiftCode = """
        import Foundation
        
        @ChimeraSchema(key: "user_v1")
        struct User: Codable {
            let userId: String
            let userName: String
            let emailAddress: String?
            let age: Int
            let address: Address
            let orders: [Order]
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case userName = "user_name"
                case emailAddress = "email"
                case age
                case address
                case orders
            }
        }
        
        struct Address: Codable {
            let street: String
            let city: String
            let zipCode: String
            
            enum CodingKeys: String, CodingKey {
                case street
                case city
                case zipCode = "zip_code"
            }
        }
        
        struct Order: Codable {
            let orderId: String
            let total: Double
        }
        
        extension Order {
            enum CodingKeys: String, CodingKey {
                case orderId = "order_id"
                case total = "total_amount"
            }
        }
        """
        
        let filePath = createTestFile(name: "Models.swift", content: swiftCode)
        
        // Test User CodingKeys
        let userKeys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "User")
        XCTAssertEqual(userKeys.count, 3)
        XCTAssertEqual(userKeys["userId"], "user_id")
        XCTAssertEqual(userKeys["userName"], "user_name")
        XCTAssertEqual(userKeys["emailAddress"], "email")
        
        // Test Address CodingKeys
        let addressKeys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Address")
        XCTAssertEqual(addressKeys.count, 1)
        XCTAssertEqual(addressKeys["zipCode"], "zip_code")
        
        // Test Order CodingKeys (in extension)
        let orderKeys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Order")
        XCTAssertEqual(orderKeys.count, 2)
        XCTAssertEqual(orderKeys["orderId"], "order_id")
        XCTAssertEqual(orderKeys["total"], "total_amount")
    }
    
    // MARK: - Property and CodingKeys Integration
    
    func testPropertyExtractionWithCodingKeys() {
        let swiftCode = """
        struct Product: Codable {
            let productId: String
            let productName: String
            let price: Double
            let tags: [String]
            let metadata: [String: String]?
            
            enum CodingKeys: String, CodingKey {
                case productId = "product_id"
                case productName = "name"
                case price
                case tags
                case metadata
            }
        }
        """
        
        let filePath = createTestFile(name: "Product.swift", content: swiftCode)
        
        // Extract properties
        let sourceCode = try! String(contentsOfFile: filePath, encoding: .utf8)
        let properties = extractProperties(from: sourceCode, typeName: "Product")
        
        XCTAssertEqual(properties.count, 5)
        
        // Extract CodingKeys
        let codingKeys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Product")
        
        // Verify mapping
        let productId = properties.first { $0.name == "productId" }
        XCTAssertNotNil(productId)
        XCTAssertEqual(codingKeys["productId"], "product_id")
        
        let productName = properties.first { $0.name == "productName" }
        XCTAssertNotNil(productName)
        XCTAssertEqual(codingKeys["productName"], "name")
        
        let tags = properties.first { $0.name == "tags" }
        XCTAssertTrue(tags?.isArray ?? false)
        
        let metadata = properties.first { $0.name == "metadata" }
        XCTAssertTrue(metadata?.isDictionary ?? false)
        XCTAssertTrue(metadata?.isOptional ?? false)
    }
    
    // MARK: - Nested Types
    
    func testNestedTypesHandling() {
        let swiftCode = """
        struct Container {
            let id: String
            let items: [Item]
            
            struct Item {
                let name: String
                let quantity: Int
            }
            
            enum CodingKeys: String, CodingKey {
                case id = "container_id"
                case items
            }
        }
        
        extension Container.Item: Codable {
            enum CodingKeys: String, CodingKey {
                case name = "item_name"
                case quantity = "qty"
            }
        }
        """
        
        let filePath = createTestFile(name: "Container.swift", content: swiftCode)
        
        // Test Container
        let containerKeys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Container")
        XCTAssertEqual(containerKeys.count, 1)
        XCTAssertEqual(containerKeys["id"], "container_id")
        
        // Note: Nested type CodingKeys in extension would need special handling
        // This test documents current behavior
    }
    
    // MARK: - Inheritance Tests
    
    func testInheritanceScenario() {
        let swiftCode = """
        class BaseModel: Codable {
            let id: String
            let createdAt: Date
            
            enum CodingKeys: String, CodingKey {
                case id = "base_id"
                case createdAt = "created_at"
            }
        }
        
        class User: BaseModel {
            let userName: String
            let email: String
            
            enum CodingKeys: String, CodingKey {
                case userName = "user_name"
                case email
            }
        }
        """
        
        let filePath = createTestFile(name: "Inheritance.swift", content: swiftCode)
        
        // Test base class
        let baseKeys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "BaseModel")
        XCTAssertEqual(baseKeys.count, 2)
        XCTAssertEqual(baseKeys["id"], "base_id")
        XCTAssertEqual(baseKeys["createdAt"], "created_at")
        
        // Test derived class
        let userKeys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "User")
        XCTAssertEqual(userKeys.count, 1)
        XCTAssertEqual(userKeys["userName"], "user_name")
    }
    
    // MARK: - Complex Real-World Example
    
    func testComplexRealWorldModel() {
        let swiftCode = """
        import Foundation
        
        @ChimeraSchema(key: "organization_v1")
        struct Organization: Codable {
            let organizationId: String
            let name: String
            let foundedYear: Int
            let headquarters: Address
            let employees: [Employee]
            let departments: Set<Department>
            let metadata: [String: String]
            
            enum CodingKeys: String, CodingKey {
                case organizationId = "org_id"
                case name = "org_name"
                case foundedYear = "founded"
                case headquarters = "hq"
                case employees
                case departments
                case metadata
            }
        }
        
        struct Employee: Codable {
            let employeeId: String
            let fullName: String
            let position: String
            let salary: Double?
            
            enum CodingKeys: String, CodingKey {
                case employeeId = "emp_id"
                case fullName = "name"
                case position = "role"
                case salary
            }
        }
        
        struct Department: Codable, Hashable {
            let name: String
            let budget: Double
        }
        
        extension Department {
            enum CodingKeys: String, CodingKey {
                case name = "dept_name"
                case budget = "yearly_budget"
            }
        }
        
        struct Address: Codable {
            let street: String
            let city: String
            let country: String
            let postalCode: String
            
            enum CodingKeys: String, CodingKey {
                case street
                case city
                case country
                case postalCode = "postal_code"
            }
        }
        """
        
        let filePath = createTestFile(name: "Organization.swift", content: swiftCode)
        
        // Test Organization
        let orgKeys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Organization")
        XCTAssertEqual(orgKeys["organizationId"], "org_id")
        XCTAssertEqual(orgKeys["name"], "org_name")
        XCTAssertEqual(orgKeys["foundedYear"], "founded")
        XCTAssertEqual(orgKeys["headquarters"], "hq")
        XCTAssertNil(orgKeys["employees"])
        
        // Test Employee
        let empKeys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Employee")
        XCTAssertEqual(empKeys["employeeId"], "emp_id")
        XCTAssertEqual(empKeys["fullName"], "name")
        XCTAssertEqual(empKeys["position"], "role")
        
        // Test Department (extension)
        let deptKeys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Department")
        XCTAssertEqual(deptKeys["name"], "dept_name")
        XCTAssertEqual(deptKeys["budget"], "yearly_budget")
        
        // Test Address
        let addressKeys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "Address")
        XCTAssertEqual(addressKeys["postalCode"], "postal_code")
        XCTAssertNil(addressKeys["street"])
        XCTAssertNil(addressKeys["city"])
    }
    
    // MARK: - Edge Cases
    
    func testEmptyFileHandling() {
        let swiftCode = ""
        let filePath = createTestFile(name: "Empty.swift", content: swiftCode)
        
        let keys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "AnyType")
        XCTAssertEqual(keys.count, 0)
    }
    
    func testFileWithOnlyImports() {
        let swiftCode = """
        import Foundation
        import SwiftUI
        """
        let filePath = createTestFile(name: "Imports.swift", content: swiftCode)
        
        let keys = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "AnyType")
        XCTAssertEqual(keys.count, 0)
    }
    
    func testMultipleTypesInSameFile() {
        let swiftCode = """
        struct TypeA: Codable {
            let value: String
            enum CodingKeys: String, CodingKey {
                case value = "value_a"
            }
        }
        
        struct TypeB: Codable {
            let value: String
            enum CodingKeys: String, CodingKey {
                case value = "value_b"
            }
        }
        
        struct TypeC: Codable {
            let value: String
            enum CodingKeys: String, CodingKey {
                case value = "value_c"
            }
        }
        """
        
        let filePath = createTestFile(name: "Multiple.swift", content: swiftCode)
        
        let keysA = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "TypeA")
        XCTAssertEqual(keysA["value"], "value_a")
        
        let keysB = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "TypeB")
        XCTAssertEqual(keysB["value"], "value_b")
        
        let keysC = CodingKeysParser.extractCodingKeys(from: filePath, typeName: "TypeC")
        XCTAssertEqual(keysC["value"], "value_c")
    }
    
    // MARK: - Nested @ChimeraPolymorphic Tests
    
    func testChimeraPolymorphicInDictionary() throws {
        // Test that @ChimeraPolymorphic types work as dictionary values
        let swiftCode = """
        import Foundation
        
        @ChimeraSchema(key: "test_dict_poly")
        struct TestModel {
            let errorMap: [String: ErrorConfig]
        }
        
        @ChimeraPolymorphic(
            schemaID: "error_config",
            key: "error_type",
            values: [
                "screen": ScreenError.self,
                "toast": ToastError.self
            ]
        )
        struct ErrorConfig {
            // Wrapper type - properties ignored
        }
        
        struct ScreenError {
            let message: String
            let title: String
        }
        
        struct ToastError {
            let duration: Int
            let text: String
        }
        """
        
        let filePath = createTestFile(name: "NestedPoly.swift", content: swiftCode)
        
        // Parse the file
        let parser = SwiftFileParser(logger: Logger(verbose: false))
        let result = try parser.extractProperties(fromFile: filePath, typeName: "TestModel")
        
        XCTAssertEqual(result.properties.count, 1)
        let errorMapProp = result.properties.first { $0.name == "errorMap" }
        XCTAssertNotNil(errorMapProp)
        XCTAssertTrue(errorMapProp?.isDictionary ?? false)
        XCTAssertEqual(errorMapProp?.typeName, "ErrorConfig")
    }
    
    func testChimeraPolymorphicInArray() throws {
        // Test that @ChimeraPolymorphic types work as array elements
        let swiftCode = """
        import Foundation
        
        @ChimeraSchema(key: "test_array_poly")
        struct TestModel {
            let errors: [ErrorItem]
        }
        
        @ChimeraPolymorphic(
            schemaID: "error_item",
            key: "type",
            values: [
                "fatal": FatalError.self,
                "warning": WarningError.self
            ]
        )
        struct ErrorItem {}
        
        struct FatalError {
            let code: Int
        }
        
        struct WarningError {
            let message: String
        }
        """
        
        let filePath = createTestFile(name: "ArrayPoly.swift", content: swiftCode)
        
        // Parse the file
        let parser = SwiftFileParser(logger: Logger(verbose: false))
        let result = try parser.extractProperties(fromFile: filePath, typeName: "TestModel")
        
        XCTAssertEqual(result.properties.count, 1)
        let errorsProp = result.properties.first { $0.name == "errors" }
        XCTAssertNotNil(errorsProp)
        XCTAssertTrue(errorsProp?.isArray ?? false)
        XCTAssertEqual(errorsProp?.typeName, "ErrorItem")
    }
    
    // MARK: - Helper Method
    
    func extractProperties(from code: String, typeName: String) -> [ExtractedProperty] {
        let sourceFile = Parser.parse(source: code)
        let visitor = PropertyExtractorVisitor(targetTypeName: typeName)
        visitor.walk(sourceFile)
        return visitor.properties
    }
}
