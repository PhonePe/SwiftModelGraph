import Foundation

@ChimeraMetaData(description: "Schema for selecting a delivery method at checkout")
@ChimeraSchema(key: "delivery_method_schema")
struct DeliveryMethod {
    @PolymorphicMapping(
        key: "type",
        values: [
            "standard": StandardDelivery.self,
            "express": ExpressDelivery.self
        ]
    )
    let model: Any
}

struct StandardDelivery {
    let type: String
    @ChimeraProperty(description: "Estimated number of business days for delivery", min: 1.0, max: 14.0)
    let estimatedDays: Int
}

struct ExpressDelivery {
    let type: String
    @ChimeraProperty(description: "Estimated number of business days for express delivery", min: 1.0, max: 3.0)
    let estimatedDays: Int
    @ChimeraProperty(description: "Priority level for express shipment", regex: ["^(high|medium|low)$"])
    let priority: String
}
