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
        case .yugioh:
            return YuGiOhAPIService()
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
            setName: mapPokemonSetIdToDisplayName(pokemonCard.set_id), // Map to display name
            subTypes: pokemonCard.subtypes?.joined(separator: ", "),
            life: nil, // Pokemon doesn't use life
            dateScrapped: nil,
            cardImageId: pokemonCard.id,
            trigger: nil, // Pokemon doesn't use triggers
            databaseUUID: pokemonCard.id  // Store the actual database UUID
        )
    }
    
    private func mapPokemonSetIdToDisplayName(_ setId: String?) -> String {
        guard let setId = setId else { return "Unknown Set" }
        
        switch setId.lowercased() {
        // Base Sets
        case "base1", "base": return "Base Set"
        case "base2": return "Base Set 2"
        case "jungle": return "Jungle"
        case "fossil": return "Fossil"
        case "base3": return "Base Set 3"
        case "base4": return "Base Set 4"
        case "base5": return "Base Set 5"
        
        // Team Rocket
        case "team_rocket", "tr": return "Team Rocket"
        
        // Gym Sets
        case "gym_heroes", "gym1": return "Gym Heroes"
        case "gym_challenge", "gym2": return "Gym Challenge"
        
        // Neo Sets
        case "neo_genesis", "neo1": return "Neo Genesis"
        case "neo_discovery", "neo2": return "Neo Discovery"
        case "neo_revelation", "neo3": return "Neo Revelation"
        case "neo_destiny", "neo4": return "Neo Destiny"
        
        // Legendary Collection
        case "legendary_collection", "lc": return "Legendary Collection"
        
        // E-Card Series
        case "expedition", "ex1": return "Expedition Base Set"
        case "aquapolis", "ex2": return "Aquapolis"
        case "skyridge", "ex3": return "Skyridge"
        
        // EX Series
        case "ex_ruby_sapphire", "rs": return "EX Ruby & Sapphire"
        case "ex_sandstorm", "ss": return "EX Sandstorm"
        case "ex_dragon", "dr": return "EX Dragon"
        case "ex_team_magma_vs_team_aqua", "ma": return "EX Team Magma vs Team Aqua"
        case "ex_hidden_legends", "hl": return "EX Hidden Legends"
        case "ex_firered_leafgreen", "fr": return "EX FireRed & LeafGreen"
        case "ex_team_rocket_returns", "tr": return "EX Team Rocket Returns"
        case "ex_deoxys", "dx": return "EX Deoxys"
        case "ex_emerald", "em": return "EX Emerald"
        case "ex_unseen_forces", "uf": return "EX Unseen Forces"
        case "ex_delta_species", "ds": return "EX Delta Species"
        case "ex_legend_maker", "lm": return "EX Legend Maker"
        case "ex_holon_phantoms", "hp": return "EX Holon Phantoms"
        case "ex_crystal_guardians", "cg": return "EX Crystal Guardians"
        case "ex_dragon_frontiers", "df": return "EX Dragon Frontiers"
        case "ex_power_keepers", "pk": return "EX Power Keepers"
        
        // Diamond & Pearl Series
        case "dp", "diamond_pearl": return "Diamond & Pearl"
        case "dp_mysterious_treasures", "mt": return "DP Mysterious Treasures"
        case "dp_secret_wonders", "sw": return "DP Secret Wonders"
        case "dp_great_encounters", "ge": return "DP Great Encounters"
        case "dp_majestic_dawn", "md": return "DP Majestic Dawn"
        case "dp_legends_awakened", "la": return "DP Legends Awakened"
        case "dp_stormfront", "sf": return "DP Stormfront"
        
        // Platinum Series
        case "platinum", "pl": return "Platinum"
        case "platinum_rising_rivals", "rr": return "Platinum Rising Rivals"
        case "platinum_supreme_victors", "sv": return "Platinum Supreme Victors"
        case "platinum_arceus", "ar": return "Platinum Arceus"
        
        // HeartGold & SoulSilver Series
        case "hgss", "heartgold_soulsilver": return "HeartGold & SoulSilver"
        case "hgss_unleashed", "ul": return "HGSS Unleashed"
        case "hgss_undaunted", "ud": return "HGSS Undaunted"
        case "hgss_triumphant", "tm": return "HGSS Triumphant"
        
        // Black & White Series
        case "bw", "black_white": return "Black & White"
        case "bw_emerging_powers", "ep": return "BW Emerging Powers"
        case "bw_noble_victories", "nv": return "BW Noble Victories"
        case "bw_next_destinies", "nd": return "BW Next Destinies"
        case "bw_dark_explorers", "de": return "BW Dark Explorers"
        case "bw_dragons_exalted", "dre": return "BW Dragons Exalted"
        case "bw_dragon_vault", "dv": return "BW Dragon Vault"
        case "bw_boundaries_crossed", "bc": return "BW Boundaries Crossed"
        case "bw_plasma_storm", "ps": return "BW Plasma Storm"
        case "bw_plasma_freeze", "pf": return "BW Plasma Freeze"
        case "bw_plasma_blast", "pb": return "BW Plasma Blast"
        case "bw_legendary_treasures", "lt": return "BW Legendary Treasures"
        
        // XY Series
        case "xy", "xy_base": return "XY Base Set"
        case "xy_flashfire", "ff": return "XY Flashfire"
        case "xy_furious_fists", "fff": return "XY Furious Fists"
        case "xy_phantom_forces", "phf": return "XY Phantom Forces"
        case "xy_primal_clash", "pc": return "XY Primal Clash"
        case "xy_roaring_skies", "ros": return "XY Roaring Skies"
        case "xy_ancient_origins", "ao": return "XY Ancient Origins"
        case "xy_breakthrough", "bkt": return "XY BREAKthrough"
        case "xy_breakpoint", "bkp": return "XY BREAKpoint"
        case "xy_fates_collide", "fcl": return "XY Fates Collide"
        case "xy_steam_siege", "sts": return "XY Steam Siege"
        case "xy_evolutions", "evo": return "XY Evolutions"
        
        // Sun & Moon Series
        case "sm", "sun_moon": return "Sun & Moon Base Set"
        case "sm_guardians_rising", "gr": return "SM Guardians Rising"
        case "sm_burning_shadows", "bs": return "SM Burning Shadows"
        case "sm_crimson_invasion", "ci": return "SM Crimson Invasion"
        case "sm_ultra_prism", "up": return "SM Ultra Prism"
        case "sm_forbidden_light", "fl": return "SM Forbidden Light"
        case "sm_celestial_storm", "ces": return "SM Celestial Storm"
        case "sm_lost_thunder", "lot": return "SM Lost Thunder"
        case "sm_team_up", "teu": return "SM Team Up"
        case "sm_detective_pikachu", "det": return "SM Detective Pikachu"
        case "sm_unbroken_bonds", "unb": return "SM Unbroken Bonds"
        case "sm_unified_minds", "unm": return "SM Unified Minds"
        case "sm_hidden_fates", "hif": return "SM Hidden Fates"
        case "sm_cosmic_eclipse", "cec": return "SM Cosmic Eclipse"
        
        // Sword & Shield Series
        case "swsh", "sword_shield": return "Sword & Shield Base Set"
        case "swsh_rebel_clash", "rck": return "SWSH Rebel Clash"
        case "swsh_darkness_ablaze", "daa": return "SWSH Darkness Ablaze"
        case "swsh_champions_path", "cpa": return "SWSH Champions Path"
        case "swsh_vivid_voltage", "viv": return "SWSH Vivid Voltage"
        case "swsh_battle_styles", "bst": return "SWSH Battle Styles"
        case "swsh_chilling_reign", "cre": return "SWSH Chilling Reign"
        case "swsh_evolving_skies", "evs": return "SWSH Evolving Skies"
        case "swsh_fusion_strike", "fsn": return "SWSH Fusion Strike"
        case "swsh_brilliant_stars", "brs": return "SWSH Brilliant Stars"
        case "swsh_astral_radiance", "pgo": return "SWSH Astral Radiance"
        case "swsh_pokemon_go", "pgo": return "SWSH Pokémon GO"
        case "swsh_lost_origin", "lor": return "SWSH Lost Origin"
        case "swsh_silver_tempest", "sit": return "SWSH Silver Tempest"
        
        // Scarlet & Violet Series
        case "sv", "scarlet_violet": return "Scarlet & Violet Base Set"
        case "sv_paldea_evolved", "pev": return "SV Paldea Evolved"
        case "sv_obsidian_flames", "obf": return "SV Obsidian Flames"
        case "sv_151", "mew": return "SV 151"
        case "sv_paradox_rift", "par": return "SV Paradox Rift"
        case "sv_paldean_fates", "paf": return "SV Paldean Fates"
        case "sv_temporal_forces", "tef": return "SV Temporal Forces"
        case "sv_twilight_masquerade", "twm": return "SV Twilight Masquerade"
        
        // Promo Sets
        case "promo", "promo_cards": return "Promotional Cards"
        case "wizards_promo", "wiz_promo": return "Wizards Promos"
        case "nintendo_promo", "nin_promo": return "Nintendo Promos"
        case "pop", "pop_series": return "POP Series"
        
        // Default case - return the original ID with some formatting
        default:
            return setId.replacingOccurrences(of: "_", with: " ")
                        .split(separator: " ")
                        .map { $0.capitalized }
                        .joined(separator: " ")
        }
    }
}

// MARK: - Yu-Gi-Oh! API Service
@MainActor
class YuGiOhAPIService: ObservableObject, TCGAPIService {
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
        ("LOB", "Legend of Blue Eyes"),
        ("MRD", "Metal Raiders"),
        ("SRL", "Spell Ruler"),
        ("PSV", "Pharaoh's Servant"),
        ("LOD", "Legacy of Darkness"),
        ("MFC", "Magician's Force"),
        ("DCR", "Dark Crisis"),
        ("IOC", "Invasion of Chaos")
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
            print("🔍 Starting Yu-Gi-Oh! search for query: '\(query)', setId: '\(setId ?? "nil")'")
            
            // Build the query for Supabase
            let response: [YuGiOhCard]
            
            if !query.isEmpty && setId != nil && !setId!.isEmpty {
                // Search with both name and type filters
                print("🔍 Searching with both name and type filters")
                response = try await supabase
                    .from("ygo_cards")
                    .select("*")
                    .ilike("name", value: "%\(query)%")
                    .eq("frame_type", value: setId!)
                    .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                    .execute()
                    .value
            } else if !query.isEmpty {
                // Search by name only
                print("🔍 Searching by name only: '\(query)'")
                response = try await supabase
                    .from("ygo_cards")
                    .select("*")
                    .ilike("name", value: "%\(query)%")
                    .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                    .execute()
                    .value
            } else if let setId = setId, !setId.isEmpty {
                // Filter by frame_type only
                print("🔍 Filtering by frame_type only: '\(setId)'")
                response = try await supabase
                    .from("ygo_cards")
                    .select("*")
                    .eq("frame_type", value: setId)
                    .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                    .execute()
                    .value
            } else {
                // No filters, get all cards
                print("🔍 Getting all Yu-Gi-Oh! cards (no filters)")
                response = try await supabase
                    .from("ygo_cards")
                    .select("*")
                    .range(from: currentPage * pageSize, to: (currentPage + 1) * pageSize - 1)
                    .execute()
                    .value
            }
            
            print("🔍 Raw Supabase response count: \(response.count)")
            if response.isEmpty {
                print("⚠️ No data returned from Supabase. Check if:")
                print("   - Table 'ygo_cards' exists")
                print("   - Column 'name' exists") 
                print("   - Data exists in the table")
                print("   - Query: '\(query)'")
            } else {
                print("✅ Found \(response.count) raw records")
                print("📝 First record: \(response.first?.name ?? "unnamed")")
            }
            
            // Convert to OnePieceCard format (generic card model used by the app)
            let newCards = response.map { yugiohCard in
                convertYuGiOhCardToTCGCard(yugiohCard)
            }
            
            if isLoadMore {
                searchResults.append(contentsOf: newCards)
            } else {
                searchResults = newCards
            }
            
            currentPage += 1
            canLoadMore = newCards.count == pageSize
            
        } catch {
            errorMessage = "Failed to search Yu-Gi-Oh! cards: \(error.localizedDescription)"
            print("🔥 Yu-Gi-Oh! search error: \(error)")
        }
        
        isLoading = false
        isLoadingMore = false
    }
    
    func loadAllSets() async {
        // Sets are hardcoded for now, but could be loaded from Supabase if needed
        print("📦 Yu-Gi-Oh! sets loaded")
    }
    
    func getAvailableSets() -> [(id: String, name: String)] {
        return availableSets
    }
    
    private func convertYuGiOhCardToTCGCard(_ yugiohCard: YuGiOhCard) -> OnePieceCard {
        return OnePieceCard(
            cardName: yugiohCard.name,
            rarity: nil, // Yu-Gi-Oh doesn't use rarity in our current schema
            cardCost: nil, // Yu-Gi-Oh doesn't use cost like One Piece
            cardPower: nil, // Could map ATK/DEF here if available
            counterAmount: nil,
            cardColor: nil, // Yu-Gi-Oh doesn't use colors like One Piece
            cardType: yugiohCard.type,
            cardText: yugiohCard.description,
            setId: yugiohCard.frameType,
            cardSetId: yugiohCard.id ?? "unknown",
            cardImage: yugiohCard.imageUrl,
            attribute: yugiohCard.frameType,
            inventoryPrice: nil, // Not available in our current schema
            marketPrice: nil, // Not available in our current schema
            setName: yugiohCard.frameType, // Using frame_type as set name
            subTypes: yugiohCard.type,
            life: nil, // Yu-Gi-Oh doesn't use life
            dateScrapped: nil,
            cardImageId: yugiohCard.id ?? "unknown",
            trigger: nil, // Yu-Gi-Oh doesn't use triggers
            databaseUUID: yugiohCard.id ?? "unknown"  // Store the actual database UUID
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
