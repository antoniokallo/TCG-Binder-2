import Foundation
import Supabase

// MARK: - Generic TCG API Protocol
protocol TCGAPIService: ObservableObject {
    var searchResults: [OnePieceCard] { get set }
    var isLoading: Bool { get set }
    var isLoadingMore: Bool { get set }
    var errorMessage: String? { get set }
    var canLoadMore: Bool { get set }
    
    func searchCards(query: String, setId: String?)
    func loadMoreResults()
    func loadAllSets() async
    func getAvailableSets() -> [(id: String, name: String)]
}

// MARK: - TCG API Factory
@MainActor
class TCGAPIFactory {
    static func createAPIService(for tcgType: TCGType) -> TCGAPIService {
        switch tcgType {
        case .onePiece:
            return OnePieceAPIService()
        case .pokemon:
            return PokemonAPIService()
        }
    }
}

// MARK: - Pokemon API Service
@MainActor
class PokemonAPIService: ObservableObject, TCGAPIService {
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
        ("base1", "Base Set"),
        ("jungle", "Jungle"),
        ("fossil", "Fossil"),
        ("base2", "Base Set 2"),
        ("team_rocket", "Team Rocket"),
        ("gym_heroes", "Gym Heroes"),
        ("gym_challenge", "Gym Challenge"),
        ("neo_genesis", "Neo Genesis")
    ]
    
    func searchCards(query: String, setId: String?) {
        Task {
            await performSearch(query: query, setId: setId, isLoadMore: false)
        }
    }
    
    func loadMoreResults() {
        Task {
            await performSearch(query: currentQuery, setId: currentSetId, isLoadMore: true)
        }
    }
    
    private func performSearch(query: String, setId: String?, isLoadMore: Bool) async {
        if isLoadMore {
            isLoadingMore = true
        } else {
            isLoading = true
            searchResults = []
            currentPage = 0
            currentQuery = query
            currentSetId = setId
        }
        
        errorMessage = nil
        
        do {
            print("🔍 Starting Pokemon search for query: '\(query)', setId: '\(setId ?? "nil")'")
            
            // Build the query for Supabase
            let response: [PokemonCardResponse]
            
            if !query.isEmpty && setId != nil && !setId!.isEmpty {
                // Search with both name and set filters
                print("🔍 Searching with both name and set filters")
                response = try await supabase
                    .from("pkm_cards")
                    .select("*")
                    .ilike("name", value: "%\(query)%")
                    .eq("set_id", value: setId!)
                    .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                    .execute()
                    .value
            } else if !query.isEmpty {
                // Search by name only
                print("🔍 Searching by name only: '\(query)'")
                response = try await supabase
                    .from("pkm_cards")
                    .select("*")
                    .ilike("name", value: "%\(query)%")
                    .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                    .execute()
                    .value
            } else if let setId = setId, !setId.isEmpty {
                // Filter by set only
                print("🔍 Filtering by set only: '\(setId)'")
                response = try await supabase
                    .from("pkm_cards")
                    .select("*")
                    .eq("set_id", value: setId)
                    .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                    .execute()
                    .value
            } else {
                // No filters, get all cards
                print("🔍 Getting all cards (no filters)")
                response = try await supabase
                    .from("pkm_cards")
                    .select("*")
                    .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                    .execute()
                    .value
            }
            
            print("🔍 Raw Supabase response count: \(response.count)")
            if response.isEmpty {
                print("⚠️ No data returned from Supabase. Check if:")
                print("   - Table 'pkm_cards' exists")
                print("   - Column 'name' exists") 
                print("   - Data exists in the table")
                print("   - Query: '\(query)'")
            } else {
                print("✅ Found \(response.count) raw records")
                print("📝 First record: \(response.first?.name ?? "unnamed")")
            }
            
            // Convert to OnePieceCard format (generic card model used by the app)
            let newCards = response.map { pokemonCard in
                convertPokemonCardToTCGCard(pokemonCard)
            }
            
            if isLoadMore {
                searchResults.append(contentsOf: newCards)
            } else {
                searchResults = newCards
            }
            
            currentPage += 1
            canLoadMore = newCards.count == pageSize
            
        } catch {
            errorMessage = "Failed to search Pokemon cards: \(error.localizedDescription)"
            print("🔥 Pokemon search error: \(error)")
        }
        
        isLoading = false
        isLoadingMore = false
    }
    
    func loadAllSets() async {
        // Sets are hardcoded for now, but could be loaded from Supabase if needed
        print("📦 Pokemon sets loaded")
    }
    
    func getAvailableSets() -> [(id: String, name: String)] {
        return availableSets
    }
    
    private func convertPokemonCardToTCGCard(_ pokemonCard: PokemonCardResponse) -> OnePieceCard {
        return OnePieceCard(
            cardName: pokemonCard.name,
            rarity: pokemonCard.rarity,
            cardCost: nil, // Pokemon doesn't use cost like One Piece
            cardPower: pokemonCard.hp != nil ? String(pokemonCard.hp!) : nil, // Convert HP to string
            counterAmount: nil,
            cardColor: pokemonCard.types?.first, // Use first type as color
            cardType: pokemonCard.types?.joined(separator: ", "),
            cardText: pokemonCard.abilities?.first?.text,
            setId: pokemonCard.set_id,
            cardSetId: pokemonCard.id,
            cardImage: pokemonCard.image_url,
            attribute: pokemonCard.subtypes?.joined(separator: ", "),
            inventoryPrice: pokemonCard.tcgplayer_market_price,
            marketPrice: pokemonCard.tcgplayer_market_price,
            setName: pokemonCard.set_id, // Could be enhanced with actual set names
            subTypes: pokemonCard.subtypes?.joined(separator: ", "),
            life: nil, // Pokemon doesn't use life
            dateScrapped: nil,
            cardImageId: pokemonCard.id,
            trigger: nil // Pokemon doesn't use triggers
        )
    }
}

// MARK: - Pokemon Card Response Model
struct PokemonCardResponse: Codable {
    let id: String
    let name: String
    let image_small: String?
    let set_id: String?
    let rarity: String?
    let hp: Int?
    let types: [String]?
    let subtypes: [String]?
    let abilities: [PokemonAbility]?
    let tcgplayer_market_price: Double?
    
    // Computed property to maintain compatibility with existing code
    var image_url: String? {
        return image_small
    }
    
    struct PokemonAbility: Codable {
        let name: String?
        let text: String?
    }
}