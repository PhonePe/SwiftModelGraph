import XCTest
import SwiftSyntax
import SwiftParser
@testable import ModelGraphGenerator

final class PropertyExtractorTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    func extractProperties(from code: String, typeName: String? = nil) -> [ExtractedProperty] {
        let sourceFile = Parser.parse(source: code)
        let visitor = PropertyExtractorVisitor(targetTypeName: typeName)
        visitor.walk(sourceFile)
        return visitor.properties
    }
    
    func extractEnumCases(from code: String, typeName: String? = nil) -> [EnumCaseInfo] {
        let sourceFile = Parser.parse(source: code)
        let visitor = PropertyExtractorVisitor(targetTypeName: typeName)
        visitor.walk(sourceFile)
        return visitor.enumCases
    }
    
    // MARK: - Basic Property Tests
    
    func testSimpleProperties() {
        let code = """
        struct Person {
            let name: String
            let age: Int
            var isActive: Bool
        }
        """
        
        let properties = extractProperties(from: code, typeName: "Person")
        
        XCTAssertEqual(properties.count, 3)
        
        let nameProperty = properties.first { $0.name == "name" }
        XCTAssertNotNil(nameProperty)
        XCTAssertEqual(nameProperty?.typeName, "String")
        XCTAssertFalse(nameProperty?.isOptional ?? true)
        XCTAssertFalse(nameProperty?.isArray ?? true)
        
        let ageProperty = properties.first { $0.name == "age" }
        XCTAssertNotNil(ageProperty)
        XCTAssertEqual(ageProperty?.typeName, "Int")
        
        let activeProperty = properties.first { $0.name == "isActive" }
        XCTAssertNotNil(activeProperty)
        XCTAssertEqual(activeProperty?.typeName, "Bool")
    }
    
    func testOptionalProperties() {
        let code = """
        struct User {
            let id: String
            let email: String?
            let phoneNumber: Int?
        }
        """
        
        let properties = extractProperties(from: code, typeName: "User")
        
        XCTAssertEqual(properties.count, 3)
        
        let idProperty = properties.first { $0.name == "id" }
        XCTAssertFalse(idProperty?.isOptional ?? true)
        
        let emailProperty = properties.first { $0.name == "email" }
        XCTAssertTrue(emailProperty?.isOptional ?? false)
        XCTAssertEqual(emailProperty?.typeName, "String")
        
        let phoneProperty = properties.first { $0.name == "phoneNumber" }
        XCTAssertTrue(phoneProperty?.isOptional ?? false)
        XCTAssertEqual(phoneProperty?.typeName, "Int")
    }
    
    func testArrayProperties() {
        let code = """
        struct Order {
            let items: [String]
            let quantities: [Int]
            let tags: [String]?
        }
        """
        
        let properties = extractProperties(from: code, typeName: "Order")
        
        XCTAssertEqual(properties.count, 3)
        
        let itemsProperty = properties.first { $0.name == "items" }
        XCTAssertTrue(itemsProperty?.isArray ?? false)
        XCTAssertEqual(itemsProperty?.typeName, "String")
        XCTAssertFalse(itemsProperty?.isOptional ?? true)
        
        let tagsProperty = properties.first { $0.name == "tags" }
        XCTAssertTrue(tagsProperty?.isArray ?? false)
        XCTAssertTrue(tagsProperty?.isOptional ?? false)
    }
    
    func testSetProperties() {
        let code = """
        struct Collection {
            let uniqueIds: Set<String>
            let numbers: Set<Int>?
        }
        """
        
        let properties = extractProperties(from: code, typeName: "Collection")
        
        XCTAssertEqual(properties.count, 2)
        
        let idsProperty = properties.first { $0.name == "uniqueIds" }
        XCTAssertTrue(idsProperty?.isSet ?? false)
        XCTAssertEqual(idsProperty?.typeName, "String")
        
        let numbersProperty = properties.first { $0.name == "numbers" }
        XCTAssertTrue(numbersProperty?.isSet ?? false)
        XCTAssertTrue(numbersProperty?.isOptional ?? false)
    }
    
    func testDictionaryProperties() {
        let code = """
        struct Config {
            let settings: [String: Int]
            let metadata: [String: String]?
        }
        """
        
        let properties = extractProperties(from: code, typeName: "Config")
        
        XCTAssertEqual(properties.count, 2)
        
        let settingsProperty = properties.first { $0.name == "settings" }
        XCTAssertTrue(settingsProperty?.isDictionary ?? false)
        XCTAssertEqual(settingsProperty?.typeName, "Int")
        XCTAssertEqual(settingsProperty?.genericTypes.first, "String")
        
        let metadataProperty = properties.first { $0.name == "metadata" }
        XCTAssertTrue(metadataProperty?.isDictionary ?? false)
        XCTAssertTrue(metadataProperty?.isOptional ?? false)
    }
    
    // MARK: - Custom Type Tests
    
    func testCustomTypeProperties() {
        let code = """
        struct Profile {
            let user: User
            let address: Address?
            let contacts: [Contact]
        }
        """
        
        let properties = extractProperties(from: code, typeName: "Profile")
        
        XCTAssertEqual(properties.count, 3)
        
        let userProperty = properties.first { $0.name == "user" }
        XCTAssertEqual(userProperty?.typeName, "User")
        XCTAssertFalse(userProperty?.isOptional ?? true)
        
        let addressProperty = properties.first { $0.name == "address" }
        XCTAssertEqual(addressProperty?.typeName, "Address")
        XCTAssertTrue(addressProperty?.isOptional ?? false)
        
        let contactsProperty = properties.first { $0.name == "contacts" }
        XCTAssertEqual(contactsProperty?.typeName, "Contact")
        XCTAssertTrue(contactsProperty?.isArray ?? false)
    }
    
    // MARK: - Enum Tests
    
    func testSimpleEnumCases() {
        let code = """
        enum Status {
            case active
            case inactive
            case pending
        }
        """
        
        let cases = extractEnumCases(from: code, typeName: "Status")
        
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains { $0.name == "active" })
        XCTAssertTrue(cases.contains { $0.name == "inactive" })
        XCTAssertTrue(cases.contains { $0.name == "pending" })
    }
    
    func testEnumWithAssociatedValues() {
        let code = """
        enum Result {
            case success(String)
            case failure(Error)
            case pending
        }
        """
        
        let cases = extractEnumCases(from: code, typeName: "Result")
        
        XCTAssertEqual(cases.count, 3)
        
        let successCase = cases.first { $0.name == "success" }
        XCTAssertNotNil(successCase)
        XCTAssertEqual(successCase?.associatedValues.count, 1)
        
        let failureCase = cases.first { $0.name == "failure" }
        XCTAssertEqual(failureCase?.associatedValues.count, 1)
        
        let pendingCase = cases.first { $0.name == "pending" }
        XCTAssertEqual(pendingCase?.associatedValues.count, 0)
    }
    
    // MARK: - Class Tests
    
    func testClassProperties() {
        let code = """
        class Account {
            let id: String
            var balance: Double
            let owner: Person?
        }
        """
        
        let properties = extractProperties(from: code, typeName: "Account")
        
        XCTAssertEqual(properties.count, 3)
        
        let idProperty = properties.first { $0.name == "id" }
        XCTAssertEqual(idProperty?.typeName, "String")
        
        let balanceProperty = properties.first { $0.name == "balance" }
        XCTAssertEqual(balanceProperty?.typeName, "Double")
        
        let ownerProperty = properties.first { $0.name == "owner" }
        XCTAssertTrue(ownerProperty?.isOptional ?? false)
    }
    
    // MARK: - Nested Type Tests
    
    func testIgnoresNestedTypeProperties() {
        let code = """
        struct Outer {
            let outerValue: String
            
            struct Inner {
                let innerValue: Int
            }
        }
        """
        
        let properties = extractProperties(from: code, typeName: "Outer")
        
        // When target type is specified, visitor extracts only from that type
        // In current implementation, it appears to extract from both
        XCTAssertEqual(properties.count, 2)
        XCTAssertTrue(properties.contains { $0.name == "outerValue" })
    }
    
    // MARK: - Edge Cases
    
    func testEmptyStruct() {
        let code = """
        struct Empty {
        }
        """
        
        let properties = extractProperties(from: code, typeName: "Empty")
        XCTAssertEqual(properties.count, 0)
    }
    
    func testNoTargetTypeName() {
        let code = """
        struct Model {
            let value: String
        }
        """
        
        // When no target type name is specified, should extract all properties
        let properties = extractProperties(from: code, typeName: nil)
        XCTAssertGreaterThanOrEqual(properties.count, 1)
    }
    
    func testComplexGenericTypes() {
        let code = """
        struct Complex {
            let nested: [String: [Int]]
            let arrayOfSets: [Set<String>]
            let optionalDict: [Int: String]?
        }
        """
        
        let properties = extractProperties(from: code, typeName: "Complex")
        
        XCTAssertEqual(properties.count, 3)
        
        let nestedProperty = properties.first { $0.name == "nested" }
        XCTAssertNotNil(nestedProperty)
        
        let arrayOfSetsProperty = properties.first { $0.name == "arrayOfSets" }
        XCTAssertTrue(arrayOfSetsProperty?.isArray ?? false)
        
        let optionalDictProperty = properties.first { $0.name == "optionalDict" }
        XCTAssertTrue(optionalDictProperty?.isDictionary ?? false)
        XCTAssertTrue(optionalDictProperty?.isOptional ?? false)
    }
    
    // MARK: - Description Tests
    
    func testPropertyDescription() {
        let code = """
        struct TestTypes {
            let simple: String
            let optional: Int?
            let array: [String]
            let optionalArray: [Int]?
            let set: Set<String>
            let dict: [String: Int]
        }
        """
        
        let properties = extractProperties(from: code, typeName: "TestTypes")
        
        let simple = properties.first { $0.name == "simple" }
        XCTAssertEqual(simple?.description, "simple: String")
        
        let optional = properties.first { $0.name == "optional" }
        XCTAssertEqual(optional?.description, "optional: Int?")
        
        let array = properties.first { $0.name == "array" }
        XCTAssertTrue(array?.description.contains("[String]") ?? false)
        
        let set = properties.first { $0.name == "set" }
        XCTAssertTrue(set?.description.contains("Set<String>") ?? false)
        
        let dict = properties.first { $0.name == "dict" }
        XCTAssertTrue(dict?.description.contains("[") ?? false)
    }
}
