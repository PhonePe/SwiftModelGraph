import Foundation

/// Test case: Polymorphic parent with children that have @ChimeraSchema annotations

// Child types with @ChimeraSchema
@ChimeraSchema(key: "deep_link_model")
struct DeepLinkActionV2: Codable {
    let type: String
    let deepLinkUrl: String
    let fallbackUrl: String?

    enum CodingKeys: String, CodingKey {
        case type
        case deepLinkUrl = "deep_link_url"
        case fallbackUrl = "fallback_url"
    }
}

@ChimeraSchema(key: "web_url_model")
struct WebUrlActionV2: Codable {
    let type: String
    let url: String
    let openInBrowser: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case url
        case openInBrowser = "open_in_browser"
    }
}

// Child type without @ChimeraSchema
struct DismissActionV2: Codable {
    let type: String
}

// Polymorphic parent
@ChimeraPolymorphic(schemaID: "notification_action_v2_schema",
                    key: "type",
                    values: [
                        "deep_link" : DeepLinkActionV2.self,
                        "web_url" : WebUrlActionV2.self,
                        "dismiss" : DismissActionV2.self
                    ])
struct NotificationActionV2: Codable {
    // Pure polymorphic wrapper
}

// Root model using the polymorphic type
@ChimeraSchema(key: "notification_v2_schema")
struct NotificationModelV2: Codable {
    let id: String
    let title: String
    let message: String
    let action: NotificationActionV2?
}
