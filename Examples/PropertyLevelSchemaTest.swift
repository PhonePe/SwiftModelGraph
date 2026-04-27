import Foundation

// Test for property-level @ChimeraSchema annotation

/// Sample polymorphic action types for testing
protocol NotificationAction: Codable {}

struct DeepLinkAction: NotificationAction, Codable {
    let type: String = "deep_link"
    let deep_link_url: String
    let fallback_url: String?
}

struct WebUrlAction: NotificationAction, Codable {
    let type: String = "web_url"
    let url: String
    let open_in_browser: Bool
}

struct DismissAction: NotificationAction, Codable {
    let type: String = "dismiss"
    let track_dismiss: Bool
}

/// Container for polymorphic actions
struct NotificationActionSchema: Codable {
    @PolymorphicMapping(
        discriminator: "type",
        variants: [
            "deep_link": DeepLinkAction.self,
            "web_url": WebUrlAction.self,
            "dismiss": DismissAction.self
        ]
    )
    let action: NotificationAction
}

/// Test struct with property-level @ChimeraSchema
/// This should generate a root-level dictionary schema with additionalProperties
struct SlotActionMap: Codable {
    /// Property-level schema annotation
    /// Should generate: { "$anchor": "slot_action_map1", "type": "object", "additionalProperties": {...} }
    @ChimeraSchema(key: "slot_action_map1")
    var config: [String: NotificationActionSchema]
    
    /// This property should be ignored since it doesn't have @ChimeraSchema
    var otherProperty: String?
}

/// Test struct with array property-level schema
struct ItemList: Codable {
    /// Should generate root-level array schema with items
    @ChimeraSchema(key: "item_list_schema")
    var items: [String]
    
    var metadata: String?
}

/// Test struct with custom type property-level schema
struct ErrorWrapper: Codable {
    /// Should expand ErrorModel properties at root level
    @ChimeraSchema(key: "error_schema")
    var error: ErrorModel
    
    var timestamp: String?
}

struct ErrorModel: Codable {
    let code: Int
    let message: String
    let details: String?
}

/// Test struct with multiple property-level schemas
/// Each @ChimeraSchema property should create a separate root schema
struct MultiSchemaTest: Codable {
    @ChimeraSchema(key: "config_schema")
    var config: [String: String]
    
    @ChimeraSchema(key: "items_schema")
    var items: [Int]
    
    var normalProperty: Bool
}
