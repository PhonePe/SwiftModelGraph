import Foundation

// Stub attribute definitions for compilation
// These allow the examples to build and create IndexStore data

// Property wrapper stubs - these do nothing but allow compilation
@propertyWrapper
struct PolymorphicMapping {
    var wrappedValue: Any

    init(wrappedValue: Any, key: String, values: [String: Any.Type]) {
        self.wrappedValue = wrappedValue
    }
}

/// Generic property wrapper stub for @ChimeraProperty.
/// Allows example files that use @ChimeraProperty on typed properties to compile.
/// The wrappedValue passes through unchanged at runtime.
@propertyWrapper
struct ChimeraProperty<T> {
    var wrappedValue: T

    init(
        wrappedValue: T,
        isDeprecated: Bool = false,
        description: String = "",
        regex: [String] = [],
        min: Double = -0.0,
        max: Double = -0.0
    ) {
        self.wrappedValue = wrappedValue
    }
}

// Attribute stubs using @attached(member) style would require macro implementation
// For now, we'll use a workaround with plain structs that the parser can see
