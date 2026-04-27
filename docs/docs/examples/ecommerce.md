---
id: ecommerce
title: E-Commerce Example
sidebar_label: E-Commerce
sidebar_position: 1
---

# E-Commerce Example

A complete example showing how to use ModelGraphGenerator for an e-commerce domain: products, orders, payments, and delivery.

## Models

### Product

```swift
@ChimeraMetaData(description: "A product available for purchase in the catalog")
@ChimeraSchema(key: "product")
struct Product {
    @ChimeraProperty(description: "Unique product identifier (SKU)")
    let id: String

    @ChimeraProperty(description: "Product display name", minLength: 1, maxLength: 200)
    let name: String

    @ChimeraProperty(description: "Full product description")
    let description: String

    @ChimeraProperty(description: "Price in USD", min: 0.0)
    let price: Double

    @ChimeraProperty(description: "Product category slug")
    let category: String

    @ChimeraProperty(description: "Image URLs")
    let imageUrls: [URL]

    @ChimeraProperty(description: "Current stock count", min: 0)
    let stockCount: Int

    @ChimeraProperty(description: "Whether the product is currently available")
    let isAvailable: Bool
}
```

### Order

```swift
@ChimeraMetaData(description: "A customer order containing one or more products")
@ChimeraSchema(key: "order")
struct Order {
    @ChimeraProperty(description: "Order identifier")
    let id: String

    @ChimeraProperty(description: "Customer identifier")
    let customerId: String

    @ChimeraProperty(description: "Ordered items")
    let items: [OrderItem]

    @ChimeraProperty(description: "Total price in USD", min: 0.0)
    let totalPrice: Double

    @ChimeraProperty(description: "Order placement timestamp")
    let placedAt: Date

    @ChimeraProperty(description: "Current order status")
    let status: OrderStatus

    @ChimeraProperty(description: "Selected payment method")
    let paymentMethod: PaymentMethod

    @ChimeraProperty(description: "Delivery information")
    let delivery: DeliveryMethod
}

enum OrderStatus: String {
    case pending, confirmed, shipped, delivered, cancelled
}
```

### Payment

```swift
@ChimeraMetaData(description: "A payment transaction for an order")
@ChimeraSchema(key: "payment")
struct Payment {
    @ChimeraProperty(description: "Payment transaction ID")
    let transactionId: String

    @ChimeraProperty(description: "Associated order ID")
    let orderId: String

    @ChimeraProperty(description: "Amount charged in USD", min: 0.0)
    let amount: Double

    @ChimeraProperty(description: "Payment gateway used")
    let gateway: String

    @ChimeraProperty(description: "Payment status")
    let status: PaymentStatus

    @ChimeraProperty(description: "Transaction timestamp")
    let processedAt: Date
}

enum PaymentStatus: String {
    case pending, authorized, captured, failed, refunded
}
```

### DeliveryMethod

```swift
@ChimeraMetaData(description: "The delivery option selected for an order")
@ChimeraSchema(key: "delivery-method")
struct DeliveryMethod {
    @ChimeraProperty(description: "Delivery provider name")
    let provider: String

    @ChimeraProperty(description: "Service tier (standard, express, overnight)")
    let tier: String

    @ChimeraProperty(description: "Estimated delivery days", min: 1, max: 30)
    let estimatedDays: Int

    @ChimeraProperty(description: "Delivery cost in USD", min: 0.0)
    let cost: Double

    @ChimeraProperty(description: "Tracking URL once shipped")
    let trackingUrl: URL?
}
```

## Running the Generator

```bash
model-graph-generator \
  --source-path ./Sources/Models/Ecommerce \
  --output ./schemas/ecommerce.json \
  --json-schema \
  --macro-only
```

## Generated Schema (excerpt)

```json
[
  {
    "schemaId": "product",
    "schemaDefinition": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
      "id": { "type": "string", "description": "Unique product identifier (SKU)" },
      "name": { "type": "string", "description": "Product display name", "minLength": 1, "maxLength": 200 },
      "description": { "type": "string", "description": "Full product description" },
      "price": { "type": "number", "description": "Price in USD", "minimum": 0.0 },
      "category": { "type": "string", "description": "Product category slug" },
      "imageUrls": {
        "type": "array",
        "items": { "type": "string", "format": "uri" },
        "description": "Image URLs"
      },
      "stockCount": { "type": "integer", "description": "Current stock count", "minimum": 0 },
      "isAvailable": { "type": "boolean", "description": "Whether the product is currently available" }
    },
    "required": ["id", "name", "description", "price", "category", "imageUrls", "stockCount", "isAvailable"]
    },
    "metaData": { "description": "A product available for purchase in the catalog" }
  }
]
```

## Key Patterns Demonstrated

| Pattern | Where Used |
|---------|-----------|
| String constraints (`minLength`, `maxLength`) | `Product.name` |
| Numeric constraints (`min`) | `price`, `stockCount` |
| Array of URLs | `Product.imageUrls` |
| Enum property | `Order.status`, `Payment.status` |
| Nested `$ref` | `Order.delivery → #delivery-method` |
| Optional property | `DeliveryMethod.trackingUrl` |
| Date-time format | `Order.placedAt`, `Payment.processedAt` |
