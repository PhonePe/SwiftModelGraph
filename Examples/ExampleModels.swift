import Foundation

@ChimeraMetaData(description: "Represents a payment transaction with support for multiple payment methods")
@ChimeraSchema(key: "sample_id_1")
struct PaymentTransaction {
    let transactionId: String
    @ChimeraProperty(description: "The total amount charged for this transaction", min: 0.0)
    let amount: Double
    @ChimeraProperty(description: "Legacy transaction type field", isDeprecated: true)
    let legacyType: String?
    @ChimeraProperty
    @PolymorphicMapping(
        key: "payment_method",
        values: [
            "credit_card": CreditCard.self,
            "paypal": PayPal.self,
            "bank_transfer": BankTransfer.self
        ]
    )
    let paymentMethod: Any
    let mapData: [Bool: WidgetProperty]
}

struct WidgetProperty {
    let data: String
    let propertyData: PropertyData
}

struct PropertyData {
    let data: String
}

struct CreditCard {
    let type: String
    @ChimeraProperty(description: "The masked credit card number", regex: ["^[0-9]{16}$"])
    let cardNumber: String
    @ChimeraProperty(description: "Card verification value", regex: ["^[0-9]{3,4}$"])
    let cvv: String
}

struct PayPal {
    let type: String
    @ChimeraProperty(description: "PayPal account email address", regex: ["^[^@]+@[^@]+\\.[^@]+$"])
    let email: String
}

struct BankTransfer {
    let type: String
    @ChimeraProperty(description: "International Bank Account Number", regex: ["^[A-Z]{2}[0-9]{2}[A-Z0-9]{1,30}$"])
    let iban: String
    @ChimeraProperty(description: "Bank Identifier Code")
    let bic: String
}

@ChimeraSchema(key: "Offer_Widget_Request")
@ChimeraMetaData(description: "Request payload for the offer widget")
struct OfferWidgetNetworkRequestData{
    let offerTags: [String]
    @ChimeraProperty(description: "Maximum number of offers to return", min: 1.0, max: 100.0)
    let limit: Int?
    @ChimeraProperty(description: "Search radius in kilometres", min: 0.0, max: 500.0)
    let radius: Double?
    let offerWidgetData: OfferWidgetData

}

@ChimeraSchema(key: "Offer_Widget_Data")
struct OfferWidgetData {
    @ChimeraProperty(key: "number_value")
    let numbers: Int
    @ChimeraProperty(key: "logo_enabled")
    let logo: Bool
}

@ChimeraMetaData(description: "Configuration for the search widget")
@ChimeraSchema(key: "search_widget_config")
struct SearchWidgetNetworkRequestData {
    @ChimeraProperty(description: "Search query string", regex: ["^.{1,256}$"])
    let query: String
    @ChimeraProperty(description: "Maximum number of results to return", min: 1.0, max: 50.0)
    let maxResults: Int
    let category: String?
}

// Multi hierarchy

@ChimeraMetaData(description: "Request payload for loading a store page")
@ChimeraSchema(key: "Store_Page_Request")
struct StorePageRequestData {
    @ChimeraProperty(description: "Unique identifier for the store")
    let storeId: String
    let storeDetails: StoreDetails
}

struct StoreDetails {
    let name: String
    let address: StoreAddress
}

struct StoreAddress {
    let city: String
    @ChimeraProperty(description: "Postal code", regex: ["^[0-9]{6}$"])
    let pincode: String
    let coordinates: GeoCoordinates
}

struct GeoCoordinates {
    @ChimeraProperty(description: "Latitude in decimal degrees", min: -90.0, max: 90.0)
    let latitude: Double
    @ChimeraProperty(description: "Longitude in decimal degrees", min: -180.0, max: 180.0)
    let longitude: Double
}

// MARK: - @ChimeraPolymorphic Test Models

/// Bottom sheet error model
struct BottomSheetModel {
    let type: String
    let title: String?
    let description: String?
    let ctaText: String?
    let imageUrl: String?
    let imageModel: ImageModel?
    let localizedTitle: LocalizationModel?
    let localizedDescription: LocalizationModel?
    let localizedCtaText: LocalizationModel?
    let ctas: [CTAModel]?
    let bottomCtas: [CTAModel]?
}

/// Error screen model
struct ErrorModels {
    let type: String
    let title: String?
    let message: [String]?
    let ctaText: String?
    let imageId: String?
    let imageModel: ImageModel?
    let localizedTitle: LocalizationModel?
    let localizedMessage: [LocalizationModel]?
    let localizedCtaText: LocalizationModel?
    let action: ActionModel?
    let ctas: [CTAModel]?
    let bottomCtas: [CTAModel]?
}

/// Image model placeholder
struct ImageModel {
    let url: String?
    let width: Int?
    let height: Int?
}

/// Localization model placeholder
struct LocalizationModel {
    let key: String?
    let defaultValue: String?
}

/// CTA model placeholder
struct CTAModel {
    let text: String?
    let action: String?
}

/// Action model placeholder
struct ActionModel {
    let type: String?
    let data: String?
}

/// Insurance error config element with polymorphic variants
@ChimeraMetaData(description: "Polymorphic error configuration for insurance flows")
@ChimeraPolymorphic(
    schemaID: "testing",
    key: "type",
    values: [
        "OPEN_ERROR_SCREEN": ErrorModels.self,
        "OPEN_BOTTOM_SHEET": BottomSheetModel.self
    ]
)
struct InsuranceErrorConfigElement {
    // Pure polymorphic wrapper - no properties
}

// MARK: - Nested @ChimeraPolymorphic Test

/// Test case for nested @ChimeraPolymorphic types
@ChimeraMetaData(description: "Test model demonstrating nested polymorphic types in various contexts")
@ChimeraSchema(key: "nested_polymorphic_test")
struct NestedPolymorphicExample {
    @ChimeraProperty(description: "Dictionary with polymorphic values")
    let errorMap: [String: InsuranceErrorConfigElement]
    
    @ChimeraProperty(description: "Array of polymorphic elements")
    let errorArray: [InsuranceErrorConfigElement]
    
    @ChimeraProperty(description: "Single optional polymorphic property")
    let singleError: InsuranceErrorConfigElement?
}
