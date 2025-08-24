import Foundation
import Supabase

// MARK: - API Models
struct OnePieceCard: Codable, Identifiable {
    let cardName: String
    let rarity: String?
    let cardCost: String?
    let cardPower: String?
    let counterAmount: Int?
    let cardColor: String?
    let cardType: String?
    let cardText: String?
    let setId: String?
    let cardSetId: String?
    let cardImage: String?
    let attribute: String?
    let inventoryPrice: Double?
    let marketPrice: Double?
    let setName: String?
    let subTypes: String?
    let life: String?
    let dateScrapped: String?
    let cardImageId: String?
    let trigger: String?
    let databaseUUID: String? // Store the actual database UUID
    
    enum CodingKeys: String, CodingKey {
        case cardName = "card_name"
        case rarity, attribute
        case cardCost = "card_cost"
        case cardPower = "card_power" 
        case counterAmount = "counter_amount"
        case cardColor = "card_color"
        case cardType = "card_type"
        case cardText = "card_text"
        case setId = "set_id"
        case cardSetId = "card_set_id"
        case cardImage = "card_image"
        case inventoryPrice = "inventory_price"
        case marketPrice = "market_price"
        case setName = "set_name"
        case subTypes = "sub_types"
        case life
        case dateScrapped = "date_scraped"
        case cardImageId = "card_image_id"
        case trigger
        case databaseUUID = "database_uuid"
    }
    
    // Identifiable requirement - use unique combination to handle parallel arts and different rarities
    var id: String { 
        if let setId = cardSetId, let imageId = cardImageId {
            // Include rarity to ensure uniqueness for same card with different rarities
            let rarityPart = rarity != nil ? "-\(rarity!)" : ""
            return "\(setId)-\(imageId)\(rarityPart)"
        } else if let setId = cardSetId {
            // Include rarity and name to ensure uniqueness
            let rarityPart = rarity != nil ? "-\(rarity!)" : ""
            let namePart = "-\(cardName.replacingOccurrences(of: " ", with: "_"))"
            return "\(setId)\(rarityPart)\(namePart)"
        } else {
            // Fallback with name and rarity
            let rarityPart = rarity != nil ? "-\(rarity!)" : ""
            let namePart = cardName.replacingOccurrences(of: " ", with: "_")
            return "\(namePart)\(rarityPart)-\(UUID().uuidString)"
        }
    }
    
    // Convenience computed properties to match old interface
    var name: String { cardName }
    var cost: String? { cardCost }
    var power: String? { cardPower }
    var counter: String? { counterAmount != nil ? "\(counterAmount!)" : nil }
    var color: String? { cardColor }
    var type: String? { cardType }
    var effect: String? { cardText }
    var number: String? { cardSetId }
    var image: String? { cardImage }
}

// MARK: - Supabase Response Model
struct OnePieceCardResponse: Codable {
    let id: String
    let name: String
    let rarity: String?
    let card_cost: FlexibleStringInt?  // Can be string or int
    let card_power: FlexibleStringInt?  // Can be string or int
    let counter_amount: Int?
    let card_color: String?
    let card_type: String?
    let card_text: String?
    let set_id: String?
    let card_set_id: String?
    let image_url: String?
    let attribute: String?
    let inventory_price: Double?
    let market_price: Double?
    let set_name: String?
    let sub_types: String?
    let life: Int?  // Changed from String? to Int?
    let date_scraped: String?
    let card_image_id: String?
    let trigger: String?
}

// Helper type to handle fields that might be stored as strings or integers
enum FlexibleStringInt: Codable {
    case string(String)
    case int(Int)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else {
            throw DecodingError.typeMismatch(FlexibleStringInt.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Int"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .int(let int):
            try container.encode(int)
        }
    }
    
    var stringValue: String? {
        switch self {
        case .string(let string):
            return string
        case .int(let int):
            return String(int)
        }
    }
}

struct OnePieceSet: Codable, Identifiable {
    let id: String
    let name: String
    let cards: [OnePieceCard]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, cards
    }
}


// MARK: - API Service
@MainActor
class OnePieceAPIService: ObservableObject, TCGAPIService {
    @Published var searchResults: [OnePieceCard] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var canLoadMore = false
    
    private var currentPage = 0
    private let pageSize = 20
    private var currentQuery = ""
    private var currentSetId: String? = nil
    
    private let availableSets: [(id: String, name: String)] = [
        ("OP-11", "A Fist of Divine Speed"),
        ("OP-10", "Royal Blood"),
        ("OP-09", "Emperors in the New World"),
        ("OP-08", "Two Legends"),
        ("OP-07", "500 Years in the Future"),
        ("OP-06", "Wings of the Captain"),
        ("OP-05", "Awakening of the New Era"),
        ("OP-04", "Kingdoms of Intrigue"),
        ("OP-03", "Pillars of Strength"),
        ("OP-02", "Paramount War"),
        ("OP-01", "Romance Dawn")
    ]
    
    func getAvailableSets() -> [(id: String, name: String)] {
        return availableSets
    }
    
    func loadAllSets() async {
        // Sets are hardcoded for now, but could be loaded from Supabase if needed
    }
    
    func searchCards(query: String, setId: String?) {
        print("🚀 OnePiece searchCards called with query: '\(query)' setId: '\(setId ?? "nil")'")
        Task {
            await performSearch(query: query, setId: setId, isLoadMore: false)
        }
    }
    
    func loadMoreResults() {
        print("🚀 OnePiece loadMoreResults called")
        Task {
            await performSearch(query: currentQuery, setId: currentSetId, isLoadMore: true)
        }
    }
    
    private func performSearch(query: String, setId: String?, isLoadMore: Bool) async {
        print("🔍 OnePiece performSearch called")
        print("🔍 Query: '\(query)'")
        print("🔍 SetId: '\(setId ?? "nil")'")
        print("🔍 IsLoadMore: \(isLoadMore)")
        
        if isLoadMore {
            isLoadingMore = true
            print("🔍 Loading more results, current page: \(currentPage)")
        } else {
            isLoading = true
            searchResults = []
            currentPage = 0
            currentQuery = query
            currentSetId = setId
            print("🔍 Starting new search, reset to page 0")
        }
        
        errorMessage = nil
        
        do {
            print("🔍 Starting Supabase query...")
            // Build the query for Supabase
            let response: [OnePieceCardResponse]
            
            if !query.isEmpty && setId != nil && !setId!.isEmpty {
                print("🔍 Searching with both name and set filters")
                print("🔍 Query: ILIKE name '%\(query)%' AND set_id = '\(setId!)'")
                response = try await supabase
                    .from("op_cards")
                    .select("*")
                    .ilike("name", value: "%\(query)%")
                    .eq("set_id", value: setId!)
                    .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                    .execute()
                    .value
            } else if !query.isEmpty {
                print("🔍 Searching by name only")
                print("🔍 Query: ILIKE name '%\(query)%'")
                response = try await supabase
                    .from("op_cards")
                    .select("*")
                    .ilike("name", value: "%\(query)%")
                    .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                    .execute()
                    .value
            } else if let setId = setId, !setId.isEmpty {
                print("🔍 Filtering by set only")
                print("🔍 Query: set_id = '\(setId)'")
                response = try await supabase
                    .from("op_cards")
                    .select("*")
                    .eq("set_id", value: setId)
                    .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                    .execute()
                    .value
            } else {
                print("🔍 Getting all cards (no filters)")
                print("🔍 Range: \(currentPage * pageSize) to \((currentPage + 1) * pageSize - 1)")
                response = try await supabase
                    .from("op_cards")
                    .select("*")
                    .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                    .execute()
                    .value
            }
            
            print("🔍 Raw Supabase response count: \(response.count)")
            if response.isEmpty {
                print("⚠️ No data returned from Supabase. Check if:")
                print("   - Table 'op_cards' exists")
                print("   - Column 'name' exists") 
                print("   - Data exists in the table")
                print("   - Query: '\(query)'")
            } else {
                print("✅ Found \(response.count) raw records")
                for (index, card) in response.prefix(3).enumerated() {
                    print("📝 Sample card \(index + 1): \(card.name)")
                    print("   - ID: \(card.id)")
                    print("   - Set ID: \(card.set_id ?? "nil")")
                    print("   - Image URL: \(card.image_url ?? "nil")")
                }
            }
            
            // Convert to OnePieceCard format
            print("🔄 Converting \(response.count) cards to OnePieceCard format...")
            let newCards = response.map { onePieceCardResponse in
                convertOnePieceCardResponseToOnePieceCard(onePieceCardResponse)
            }
            print("✅ Converted \(newCards.count) cards successfully")
            
            // Debug: Show generated IDs to ensure uniqueness
            print("🆔 Generated IDs for cards:")
            for (index, card) in newCards.prefix(5).enumerated() {
                print("   \(index + 1). \(card.name) (\(card.rarity ?? "no rarity")) -> ID: \(card.id)")
            }
            
            if isLoadMore {
                searchResults.append(contentsOf: newCards)
                print("📋 Added \(newCards.count) cards to existing \(searchResults.count - newCards.count) results")
            } else {
                searchResults = newCards
                print("📋 Set search results to \(newCards.count) cards")
            }
            
            currentPage += 1
            canLoadMore = newCards.count == pageSize
            print("📄 Updated to page \(currentPage), canLoadMore: \(canLoadMore)")
            
        } catch {
            print("❌ One Piece search error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            errorMessage = "Failed to search One Piece cards: \(error.localizedDescription)"
        }
        
        print("🏁 Search completed: \(searchResults.count) total results")
        isLoading = false
        isLoadingMore = false
    }
    
    private func convertOnePieceCardResponseToOnePieceCard(_ response: OnePieceCardResponse) -> OnePieceCard {
        return OnePieceCard(
            cardName: response.name,
            rarity: response.rarity,
            cardCost: response.card_cost?.stringValue,
            cardPower: response.card_power?.stringValue,
            counterAmount: response.counter_amount,
            cardColor: response.card_color,
            cardType: response.card_type,
            cardText: response.card_text,
            setId: response.set_id,
            cardSetId: response.card_set_id,
            cardImage: response.image_url,
            attribute: response.attribute,
            inventoryPrice: response.inventory_price,
            marketPrice: response.market_price,
            setName: response.set_name,
            subTypes: response.sub_types,
            life: response.life != nil ? String(response.life!) : nil,  // Convert Int to String
            dateScrapped: response.date_scraped,
            cardImageId: response.card_image_id,
            trigger: response.trigger,
            databaseUUID: response.id  // Store the actual database UUID
        )
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError:
            return "Server error"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}
