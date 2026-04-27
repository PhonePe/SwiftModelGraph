import XCTest
import Foundation
@testable import ModelGraphGenerator

final class ModelsTests: XCTestCase {
    
    // MARK: - ModelGraph Tests
    
    func testModelGraphCodable() throws {
        let graph = ModelGraph(
            generatedAt: "2026-02-06T10:00:00Z",
            roots: []
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(graph)
        let jsonString = String(data: jsonData, encoding: .utf8)
        
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString?.contains("generatedAt") ?? false)
        XCTAssertTrue(jsonString?.contains("roots") ?? false)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedGraph = try decoder.decode(ModelGraph.self, from: jsonData)
        
        XCTAssertEqual(decodedGraph.generatedAt, graph.generatedAt)
        XCTAssertEqual(decodedGraph.roots.count, graph.roots.count)
    }
    
    // MARK: - ModelNode Tests
    
    func testModelNodeCreation() {
        let node = ModelNode(
            name: "User",
            kind: "struct",
            filePath: "/path/to/User.swift",
            line: 10,
            schemaId: "user_v1",
            inheritsFrom: nil,
            inheritedProperties: [],
            properties: [],
            enumCases: [],
            children: [],
            isCyclic: false,
            parentPropertyName: nil
        )
        
        XCTAssertEqual(node.name, "User")
        XCTAssertEqual(node.kind, "struct")
        XCTAssertEqual(node.schemaId, "user_v1")
        XCTAssertFalse(node.isCyclic)
    }
    
    func testModelNodeCodable() throws {
        let property = PropertyInfo(
            name: "userId",
            typeName: "String",
            isOptional: false,
            isArray: false,
            isSet: false,
            isDictionary: false,
            dictionaryKeyType: nil,
            codingKey: "user_id"
        )

        let node = ModelNode(
            name: "User",
            kind: "struct",
            filePath: "/path/to/User.swift",
            line: 10,
            schemaId: nil,
            inheritsFrom: nil,
            inheritedProperties: [],
            properties: [property],
            enumCases: [],
            children: [],
            isCyclic: false,
            parentPropertyName: nil
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(node)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ModelNode.self, from: jsonData)
        
        XCTAssertEqual(decoded.name, node.name)
        XCTAssertEqual(decoded.properties.count, 1)
        XCTAssertEqual(decoded.properties[0].name, "userId")
    }
    
    func testModelNodeWithChildren() {
        let childNode = ModelNode(
            name: "Address",
            kind: "struct",
            filePath: "/path/to/Address.swift",
            line: 5,
            schemaId: nil,
            inheritsFrom: nil,
            inheritedProperties: [],
            properties: [],
            enumCases: [],
            children: [],
            isCyclic: false,
            parentPropertyName: "address"
        )
        
        let parentNode = ModelNode(
            name: "User",
            kind: "struct",
            filePath: "/path/to/User.swift",
            line: 10,
            schemaId: nil,
            inheritsFrom: nil,
            inheritedProperties: [],
            properties: [],
            enumCases: [],
            children: [childNode],
            isCyclic: false,
            parentPropertyName: nil
        )
        
        XCTAssertEqual(parentNode.children.count, 1)
        XCTAssertEqual(parentNode.children[0].name, "Address")
        XCTAssertEqual(parentNode.children[0].parentPropertyName, "address")
    }
    
    // MARK: - PropertyInfo Tests
    
    func testPropertyInfoSimple() {
        let property = PropertyInfo(
            name: "id",
            typeName: "String",
            isOptional: false,
            isArray: false,
            isSet: false,
            isDictionary: false,
            dictionaryKeyType: nil
        )
        
        XCTAssertEqual(property.name, "id")
        XCTAssertEqual(property.typeName, "String")
        XCTAssertFalse(property.isOptional)
        XCTAssertFalse(property.isArray)
    }
    
    func testPropertyInfoOptional() {
        let property = PropertyInfo(
            name: "email",
            typeName: "String",
            isOptional: true,
            isArray: false,
            isSet: false,
            isDictionary: false,
            dictionaryKeyType: nil,
            codingKey: "email_address"
        )
        
        XCTAssertTrue(property.isOptional)
        XCTAssertEqual(property.codingKey, "email_address")
    }
    
    func testPropertyInfoArray() {
        let property = PropertyInfo(
            name: "items",
            typeName: "Item",
            isOptional: false,
            isArray: true,
            isSet: false,
            isDictionary: false,
            dictionaryKeyType: nil
        )
        
        XCTAssertTrue(property.isArray)
        XCTAssertFalse(property.isSet)
        XCTAssertFalse(property.isDictionary)
    }
    
    func testPropertyInfoSet() {
        let property = PropertyInfo(
            name: "tags",
            typeName: "String",
            isOptional: false,
            isArray: false,
            isSet: true,
            isDictionary: false,
            dictionaryKeyType: nil
        )
        
        XCTAssertTrue(property.isSet)
        XCTAssertFalse(property.isArray)
    }
    
    func testPropertyInfoDictionary() {
        let property = PropertyInfo(
            name: "metadata",
            typeName: "String",
            isOptional: false,
            isArray: false,
            isSet: false,
            isDictionary: true,
            dictionaryKeyType: nil
        )
        
        XCTAssertTrue(property.isDictionary)
    }
    
    func testPropertyInfoCodable() throws {
        let property = PropertyInfo(
            name: "userId",
            typeName: "String",
            isOptional: true,
            isArray: false,
            isSet: false,
            isDictionary: false,
            dictionaryKeyType: nil,
            codingKey: "user_id"
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(property)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PropertyInfo.self, from: jsonData)
        
        XCTAssertEqual(decoded.name, property.name)
        XCTAssertEqual(decoded.typeName, property.typeName)
        XCTAssertEqual(decoded.isOptional, property.isOptional)
        XCTAssertEqual(decoded.codingKey, property.codingKey)
    }
    
    // MARK: - EnumCaseInfo Tests
    
    func testEnumCaseInfoSimple() {
        let enumCase = EnumCaseInfo(
            name: "active",
            associatedValues: [],
            rawValue: nil
        )
        
        XCTAssertEqual(enumCase.name, "active")
        XCTAssertEqual(enumCase.associatedValues.count, 0)
    }
    
    func testEnumCaseInfoWithAssociatedValues() {
        let enumCase = EnumCaseInfo(
            name: "error",
            associatedValues: ["String", "Int"],
            rawValue: nil
        )
        
        XCTAssertEqual(enumCase.name, "error")
        XCTAssertEqual(enumCase.associatedValues.count, 2)
        XCTAssertEqual(enumCase.associatedValues[0], "String")
        XCTAssertEqual(enumCase.associatedValues[1], "Int")
    }
    
    func testEnumCaseInfoCodable() throws {
        let enumCase = EnumCaseInfo(
            name: "success",
            associatedValues: ["String"],
            rawValue: nil
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(enumCase)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EnumCaseInfo.self, from: jsonData)
        
        XCTAssertEqual(decoded.name, enumCase.name)
        XCTAssertEqual(decoded.associatedValues, enumCase.associatedValues)
    }
    
    // MARK: - InheritedPropertyInfo Tests
    
    func testInheritedPropertyInfo() {
        let inherited = InheritedPropertyInfo(
            name: "id",
            typeName: "String",
            isOptional: false,
            isArray: false,
            isSet: false,
            isDictionary: false,
            codingKey: nil,
            declaredIn: "BaseModel",
            originallyDeclaredIn: "BaseModel",
            filePath: "/path/to/Base.swift",
            line: 10
        )
        
        XCTAssertEqual(inherited.declaredIn, "BaseModel")
        XCTAssertEqual(inherited.name, "id")
    }
    
    func testInheritedPropertyInfoCodable() throws {
        let inherited = InheritedPropertyInfo(
            name: "timestamp",
            typeName: "Date",
            isOptional: false,
            isArray: false,
            isSet: false,
            isDictionary: false,
            codingKey: "created_at",
            declaredIn: "Timestamped",
            originallyDeclaredIn: "Timestamped",
            filePath: "/path/to/Timestamped.swift",
            line: 5
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(inherited)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(InheritedPropertyInfo.self, from: jsonData)
        
        XCTAssertEqual(decoded.declaredIn, inherited.declaredIn)
        XCTAssertEqual(decoded.codingKey, inherited.codingKey)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteGraphSerialization() throws {
        let childProperty = PropertyInfo(
            name: "street",
            typeName: "String",
            isOptional: false,
            isArray: false,
            isSet: false,
            isDictionary: false,
            dictionaryKeyType: nil
        )
        
        let childNode = ModelNode(
            name: "Address",
            kind: "struct",
            filePath: "/path/to/Address.swift",
            line: 5,
            schemaId: nil,
            inheritsFrom: nil,
            inheritedProperties: [],
            properties: [childProperty],
            enumCases: [],
            children: [],
            isCyclic: false,
            parentPropertyName: "address"
        )
        
        let parentProperty = PropertyInfo(
            name: "name",
            typeName: "String",
            isOptional: false,
            isArray: false,
            isSet: false,
            isDictionary: false,
            dictionaryKeyType: nil,
            codingKey: "full_name"
        )
        
        let parentNode = ModelNode(
            name: "User",
            kind: "struct",
            filePath: "/path/to/User.swift",
            line: 10,
            schemaId: "user_v1",
            inheritsFrom: nil,
            inheritedProperties: [],
            properties: [parentProperty],
            enumCases: [],
            children: [childNode],
            isCyclic: false,
            parentPropertyName: nil
        )
        
        let graph = ModelGraph(
            generatedAt: "2026-02-06T10:00:00Z",
            roots: [parentNode]
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(graph)
        
        // Verify it can be decoded
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ModelGraph.self, from: jsonData)
        
        XCTAssertEqual(decoded.roots.count, 1)
        XCTAssertEqual(decoded.roots[0].name, "User")
        XCTAssertEqual(decoded.roots[0].children.count, 1)
        XCTAssertEqual(decoded.roots[0].children[0].name, "Address")
    }
}
