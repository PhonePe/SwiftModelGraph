import Foundation

@ChimeraMetaData(description: "Home page configuration with multiple widget types")
@ChimeraMultiKnot(
    schemaId = "home_page_schema_v1",
    subSchemas = [OfferWidgetNetworkRequestData.class, SearchWidgetNetworkRequestData.class]
)
struct HomePageConfig {}

@ChimeraSchema(key: "ABC_widgets")
struct OfferWidgetNetworkRequestData {
    let offerTags: List<String>
    let limit: Int?
    let radius: Double?
}

@ChimeraSchema(key: "search_widget_knot")
struct SearchWidgetNetworkRequestData {
    let query: String
    let maxResults: Int
    let category: String?
}
