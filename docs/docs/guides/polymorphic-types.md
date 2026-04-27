---
id: polymorphic-types
title: Polymorphic Types
sidebar_label: Polymorphic Types
sidebar_position: 2
---

# Polymorphic Types

ModelGraphGenerator supports polymorphic Swift types — protocols or base classes where a property can hold one of several concrete types. These are emitted as `oneOf` schemas in JSON Schema Draft 2020-12.

## Overview

Polymorphism in Swift typically uses protocols:

```swift
protocol Shape {}
struct Circle: Shape { let radius: Double }
struct Rectangle: Shape { let width: Double; let height: Double }
```

When a property holds a `Shape`, the JSON Schema needs to express "this can be a Circle **or** a Rectangle." That is a `oneOf` schema.

ModelGraphGenerator detects this pattern via the `@PolymorphicMapping` annotation.

---

## `@PolymorphicMapping`

Apply `@PolymorphicMapping` to a protocol or base class that is used as a property type in a `@ChimeraSchema`.

```swift
@PolymorphicMapping(
    key: "type",
    mappings: [
        "circle": Circle.self,
        "rectangle": Rectangle.self,
        "triangle": Triangle.self
    ]
)
protocol Shape {}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `String` | The discriminator property name (e.g., `"type"`, `"kind"`) |
| `mappings` | `[String: Any.Type]` | Dictionary mapping discriminator values to concrete types |

### How It Works

When ModelGraphGenerator encounters a property typed as `Shape`:

1. It looks up the `@PolymorphicMapping` for `Shape`
2. It generates a `oneOf` schema with each concrete type's schema
3. It adds a `discriminator` field using the specified `key`

---

## Complete Example

### Swift Source

```swift
// Define concrete types
@ChimeraMetaData(description: "A circle shape")
@ChimeraSchema(key: "circle")
struct Circle: Shape {
    @ChimeraProperty(description: "Radius in pixels", min: 0.0)
    let radius: Double

    @ChimeraProperty(description: "Fill color as hex")
    let color: String
}

@ChimeraMetaData(description: "A rectangle shape")
@ChimeraSchema(key: "rectangle")
struct Rectangle: Shape {
    @ChimeraProperty(description: "Width in pixels", min: 0.0)
    let width: Double

    @ChimeraProperty(description: "Height in pixels", min: 0.0)
    let height: Double

    @ChimeraProperty(description: "Fill color as hex")
    let color: String
}

// Mark the protocol as polymorphic
@PolymorphicMapping(
    key: "type",
    mappings: [
        "circle": Circle.self,
        "rectangle": Rectangle.self
    ]
)
protocol Shape {}

// Use it in a root model
@ChimeraMetaData(description: "A drawing canvas")
@ChimeraSchema(key: "canvas")
struct Canvas {
    @ChimeraProperty(description: "Canvas title")
    let title: String

    @ChimeraProperty(description: "Shapes on the canvas")
    let shapes: [Shape]
}
```

### Generated JSON Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "title": {
      "type": "string",
      "description": "Canvas title"
    },
    "shapes": {
      "type": "array",
      "description": "Shapes on the canvas",
      "items": {
        "oneOf": [
          {
            "$ref": "#circle",
            "description": "A circle shape"
          },
          {
            "$ref": "#rectangle",
            "description": "A rectangle shape"
          }
        ],
        "discriminator": {
          "propertyName": "type",
          "mapping": {
            "circle": "#circle",
            "rectangle": "#rectangle"
          }
        }
      }
    }
  },
  "required": ["title", "shapes"]
}
```

---

## Discriminator Property

The `key` in `@PolymorphicMapping` maps to the JSON Schema `discriminator.propertyName`. This tells schema validators and code generators which property to inspect when choosing the concrete type.

In the example above, a JSON payload would include a `"type"` field:

```json
// A circle
{ "type": "circle", "radius": 50.0, "color": "#FF5733" }

// A rectangle
{ "type": "rectangle", "width": 100.0, "height": 60.0, "color": "#3399FF" }
```

---

## Class Inheritance

`@PolymorphicMapping` also works with class hierarchies:

```swift
@PolymorphicMapping(
    key: "vehicleType",
    mappings: [
        "car": Car.self,
        "truck": Truck.self,
        "motorcycle": Motorcycle.self
    ]
)
class Vehicle {
    let make: String
    let model: String
}

class Car: Vehicle {
    let doors: Int
}

class Truck: Vehicle {
    let payloadTons: Double
}
```

---

## Tips and Limitations

- All concrete types in `mappings` should themselves be `@ChimeraSchema`-annotated for best results
- Discriminator values are arbitrary strings — use meaningful names like `"circle"`, `"rectangle"`
- Deeply nested polymorphic types are supported
- Circular references between polymorphic types are detected and result in a build warning
