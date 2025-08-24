import Foundation
import SwiftUI

// Data structure for each individual binder
struct BinderData: Codable {
    var sets: [TCGSet] = []
    var currentSetID: String? = nil
    var spreadIndexBySet: [String: Int] = [:]
    var binderName: String = ""
    var selectedTCG: TCGType = .onePiece
    var cardCache: [String: OnePieceCard] = [:]
}

@MainActor
final class BinderViewModel: ObservableObject {
    @Published var sets: [TCGSet] = []
    @Published var currentSetID: String? = nil
    @Published var query: String = ""
    @Published var searchResults: [TCGCard] = []
    @Published var spreadIndexBySet: [String: Int] = [:]
    @Published var binderName: String = "My TCG Binder"
    @Published var selectedTCG: TCGType = .onePiece
    @Published var selectedBinder: BinderType = .black
    @Published var userBinders: [UserBinder] = []
    @Published var selectedUserBinder: UserBinder?
    
    // Pokemon persistence service
    private let pokemonPersistenceService = PokemonCardPersistenceService()
    
    // Yu-Gi-Oh! persistence service
    private let yugiohPersistenceService = YuGiOhCardPersistenceService()
    
    // One Piece persistence service
    private let onepiecePersistenceService = OnePieceCardPersistenceService()
    
    // User binder service for value management
    private let userBinderService = UserBinderService()
    
    // Binder-specific card service
    private let binderCardService = BinderCardService()
    
    // Track if Pokemon cards have been loaded this session (per binder)
    private var pokemonCardsLoadedThisSession: [BinderType: Bool] = [:]
    
    // Track if Yu-Gi-Oh! cards have been loaded this session (per binder)
    private var yugiohCardsLoadedThisSession: [BinderType: Bool] = [:]
    
    // Track if One Piece cards have been loaded this session (per binder)
    private var onepieceCardsLoadedThisSession: [BinderType: Bool] = [:]
    
    // Binder numbers
    @Published var binderNumbers: [BinderType: Int] = [:]
    
    // Separate data for each binder type
    private var binderData: [BinderType: BinderData] = [:]

    private let selectedTCGKey = "binder.selectedTCG"
    private let selectedBinderKey = "binder.selectedBinder"
    
    // Binder-specific storage keys
    private var binderDataKey: String { "binder.data.\(selectedBinder.rawValue)" }
    
    // Separate cache for full API card data
    private var cardCache: [String: OnePieceCard] = [:]

    init() {
        // Check if this is a fresh install or if we want to clear data
        let ud = UserDefaults.standard
        let hasLaunchedBefore = ud.bool(forKey: "hasLaunchedBefore")
        
        if !hasLaunchedBefore {
            // Clear any residual data from previous installs
            clearAllDataSilently()
            ud.set(true, forKey: "hasLaunchedBefore")
        }
        
        loadPersistedInitial()
        loadMockSets()
        
        if currentSetID == nil { 
            currentSetID = sets.first?.id 
        }
        
        // Initialize binder data
        loadBinderData()
        
        // Load user binders from Supabase
        Task {
            await loadUserBinders()
        }
    }

    // MARK: - Paging

    func pages(for set: TCGSet) -> [[TCGCard]] {
        let pageSize = 9  // 3x3 grid per page
        var result: [[TCGCard]] = []
        var index = 0
        while index < set.cards.count {
            let end = min(index + pageSize, set.cards.count)
            result.append(Array(set.cards[index..<end]))
            index += pageSize
        }
        return result
    }

    func currentPageIndex(for setID: String) -> Int {
        spreadIndexBySet[setID] ?? 0
    }

    func setPageIndex(_ i: Int, for setID: String) {
        spreadIndexBySet[setID] = i
        persist()
    }

    // MARK: - Search

    func runSearch() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { searchResults = []; return }
        let allCards = sets.flatMap { $0.cards }
        searchResults = allCards.filter { card in
            card.name.lowercased().contains(q) || card.setID.lowercased().contains(q)
        }
    }

    func jump(to card: TCGCard) {
        currentSetID = card.setID
        guard let set = sets.first(where: { $0.id == card.setID }) else { return }
        let idx = set.cards.firstIndex(of: card) ?? 0
        let page = idx / 9  // 9 cards per page
        setPageIndex(page, for: set.id)
        query = ""
        searchResults = []
    }

    
    // MARK: - Add New Card
    
    func addNewCard(name: String, imageURL: String?, rarity: String?, to setID: String) {
        guard let setIndex = sets.firstIndex(where: { $0.id == setID }) else { return }
        
        let cardID = "\(setID)-\(sets[setIndex].cards.count + 1)"
        let url = URL(string: imageURL ?? "about:blank") ?? URL(string: "about:blank")!
        
        let newCard = TCGCard(
            id: cardID,
            name: name,
            imageURL: url,
            setID: setID,
            rarity: rarity
        )
        
        sets[setIndex].cards.append(newCard)
        
        // Navigate to the page containing the new card
        let cardIndex = sets[setIndex].cards.count - 1
        let pageIndex = cardIndex / 9
        setPageIndex(pageIndex, for: setID)
        
        // Persist the changes
        persist()
    }
    
    func addOnePieceCard(_ onePieceCard: OnePieceCard, to setID: String) {
        guard let setIndex = sets.firstIndex(where: { $0.id == setID }) else { 
            return 
        }
        
        let cardID = "\(setID)-\(sets[setIndex].cards.count + 1)"
        let url = URL(string: onePieceCard.cardImage ?? "about:blank") ?? URL(string: "about:blank")!
        
        // Cache the full API data separately
        cardCache[cardID] = onePieceCard
        
        // Create simplified binder card
        let newCard = TCGCard(
            id: cardID,
            name: onePieceCard.name,
            imageURL: url,
            setID: setID,
            rarity: onePieceCard.rarity,
            cardCost: onePieceCard.cardCost,
            cardPower: onePieceCard.cardPower,
            counterAmount: onePieceCard.counterAmount,
            cardColor: onePieceCard.cardColor,
            cardType: onePieceCard.cardType,
            cardText: onePieceCard.cardText,
            attribute: onePieceCard.attribute,
            inventoryPrice: onePieceCard.inventoryPrice,
            marketPrice: onePieceCard.marketPrice,
            subTypes: onePieceCard.subTypes,
            life: onePieceCard.life,
            trigger: onePieceCard.trigger
        )
        
        // Check if we're working with a binder vs regular collection
        if let selectedBinder = selectedUserBinder, let binderId = selectedBinder.id {
            // For binders: Don't add to local sets, only save to binder database
            // Use the card's actual database UUID
            let cardUUIDToUse = onePieceCard.databaseUUID ?? onePieceCard.id
            print("🔍 DEBUG: Using database UUID: '\(cardUUIDToUse)' for binder: '\(binderId)'")
            print("💾 DEBUG: Saving card name: '\(onePieceCard.cardName)', rarity: '\(onePieceCard.rarity ?? "nil")'")
            print("💾 DEBUG: Card image: '\(onePieceCard.cardImage ?? "nil")'")
            
            Task {
                do {
                    try await binderCardService.addCardToBinderWithUUID(
                        binderId: binderId,
                        cardUUID: cardUUIDToUse,
                        cardType: selectedTCG
                    )
                    print("✅ Successfully added card to binder!")
                    
                    // Refresh the binder to show the new card
                    await MainActor.run {
                        // Clear the session cache to force reload
                        let sessionKey = "\(binderId)-\(selectedTCG.rawValue)"
                        cardsLoadedThisSession[sessionKey] = false
                    }
                    
                    // Force reload cards from binder to show the newly added card
                    await loadCardsIfNeeded(forceRefresh: true)
                    
                } catch {
                    print("❌ Failed to add card to binder: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                }
            }
        } else {
            // For regular collection: Add to local sets array as before
            sets[setIndex].cards.append(newCard)
            
            // Navigate to the page containing the new card
            let cardIndex = sets[setIndex].cards.count - 1
            let pageIndex = cardIndex / 9
            setPageIndex(pageIndex, for: setID)
        }
        
        // Persist the changes
        persist()
    }

    // MARK: - Card Cache Access
    
    func getCachedCardData(for cardID: String) -> OnePieceCard? {
        return cardCache[cardID]
    }
    
    // MARK: - Binder-Specific Card Loading
    
    func loadCardsIfNeeded(forceRefresh: Bool = false) async {
        guard let selectedBinder = selectedUserBinder, let binderId = selectedBinder.id else {
            print("⚠️ No selected binder to load cards from")
            return
        }
        
        print("🔍 DEBUG: loadCardsIfNeeded called for binder: \(binderId)")
        
        // Check if we already have cards loaded for this binder (prevent duplicates)
        let hasCards = sets.first?.cards.contains { card in
            card.id.contains("-binder-") || cardCache[card.id] != nil
        } ?? false
        
        // If we already loaded cards for this binder this session, skip
        let sessionKey = "\(binderId)-\(selectedTCG.rawValue)"
        let alreadyLoaded = cardsLoadedThisSession[sessionKey] ?? false
        
        print("🔍 DEBUG: hasCards: \(hasCards), alreadyLoaded: \(alreadyLoaded), sessionKey: \(sessionKey), forceRefresh: \(forceRefresh)")
        
        // Skip loading if already loaded this session, unless we're forcing a refresh
        if alreadyLoaded && !forceRefresh {
            print("🚫 DEBUG: Skipping load - cards already loaded this session")
            return
        }
        
        // Skip if we already have cards loaded, unless we're forcing a refresh
        if hasCards && !forceRefresh {
            print("🚫 DEBUG: Skipping load - cards already present in UI")
            return
        }
        
        print("⬇️ DEBUG: Proceeding with card load")
        // Set the flag BEFORE loading to prevent race conditions
        cardsLoadedThisSession[sessionKey] = true
        await loadCardsFromBinder(binderId: binderId)
    }
    
    // Track if cards have been loaded this session (per binder + TCG combination)
    private var cardsLoadedThisSession: [String: Bool] = [:]
    
    // MARK: - Session Management
    
    func clearSessionCache() {
        cardsLoadedThisSession.removeAll()
        print("🧹 Cleared session cache for card loading")
    }
    
    @MainActor
    private func loadCardsFromBinder(binderId: String) async {
        print("🔄 DEBUG: loadCardsFromBinder called for binderId: \(binderId)")
        print("📍 DEBUG: Call stack trace")
        
        do {
            // Clear existing cards to prevent duplicates
            clearCurrentBinderCards()
            
            // Load cards specific to this binder and TCG type
            let binderCards = try await binderCardService.loadCardsForBinder(binderId: binderId)
            
            // Filter cards by current TCG type (cards in binder can be mixed TCG types)
            let filteredCards = binderCards // For now, load all cards - we could filter by type later
            
            guard !filteredCards.isEmpty else {
                print("📭 No cards found in binder for \(selectedTCG.rawValue)")
                return
            }
            
            // Get the actual card data from respective databases
            let cardDetails = try await binderCardService.getCardDetails(for: filteredCards, cardType: selectedTCG)
            
            print("📤 DEBUG: Loaded card details from database:")
            for (index, cardDetail) in cardDetails.enumerated() {
                print("   Card \(index + 1): name='\(cardDetail.cardName)', rarity='\(cardDetail.rarity ?? "nil")'")
                print("   Card \(index + 1): image='\(cardDetail.cardImage ?? "nil")'")
                print("   Card \(index + 1): setId='\(cardDetail.setId ?? "nil")', cardSetId='\(cardDetail.cardSetId ?? "nil")'")
            }
            
            // Create a lookup dictionary for quantities
            let quantityLookup = Dictionary(uniqueKeysWithValues: filteredCards.map { ($0.cardId, Int($0.qty)) })
            
            // Add cards to binder with proper quantities
            for cardDetail in cardDetails {
                let cardId = cardDetail.cardSetId ?? cardDetail.id
                let quantity = quantityLookup[cardId] ?? 1
                
                // Add multiple copies based on quantity
                if let firstSet = sets.first, quantity > 0 {
                    for copyIndex in 1...quantity {
                        let binderCardId = "\(firstSet.id)-\(cardDetail.name)-\(cardId)-binder-copy\(copyIndex)"
                        addCardToSet(cardDetail, setId: firstSet.id, binderCardId: binderCardId)
                    }
                }
            }
            
            print("✅ Loaded \(cardDetails.count) card types with total copies from binder")
            
            // Debug: Print final card count in sets
            let totalCardsInSets = sets.flatMap { $0.cards }.count
            print("🔢 DEBUG: Total cards now in sets array: \(totalCardsInSets)")
            if let firstSet = sets.first {
                print("🔢 DEBUG: Cards in first set: \(firstSet.cards.count)")
                print("🔢 DEBUG: First few card names: \(firstSet.cards.prefix(3).map { $0.name })")
            }
            
        } catch {
            print("❌ Failed to load cards from binder: \(error)")
        }
    }
    
    @MainActor
    private func clearCurrentBinderCards() {
        // Clear existing binder cards (those with "-binder-" in the ID)
        for setIndex in sets.indices {
            sets[setIndex].cards.removeAll { card in
                card.id.contains("-binder-") || cardCache[card.id] != nil
            }
        }
        
        // Clear the card cache for binder cards
        let keysToRemove = cardCache.keys.filter { key in
            key.contains("-binder-")
        }
        for key in keysToRemove {
            cardCache.removeValue(forKey: key)
        }
    }
    
    func loadYuGiOhCardsIfNeeded() async {
        // Only load if we're in Yu-Gi-Oh! mode
        guard selectedTCG == .yugioh else {
            return
        }
        
        // Check if we already have Yu-Gi-Oh! cards loaded for this binder (prevent duplicates)
        let hasYugiohCards = sets.first?.cards.contains { card in
            card.id.contains("-ygo-copy") || cardCache[card.id] != nil
        } ?? false
        
        // If we already loaded cards for this binder this session and they're still there, skip
        if hasYugiohCards && (yugiohCardsLoadedThisSession[selectedBinder] ?? false) {
            return
        }
        
        await loadYuGiOhCardsFromSupabase()
        yugiohCardsLoadedThisSession[selectedBinder] = true
    }
    
    func loadOnePieceCardsIfNeeded() async {
        // Only load if we're in One Piece mode
        guard selectedTCG == .onePiece else {
            return
        }
        
        // Check if we already have One Piece cards loaded for this binder (prevent duplicates)
        let hasOnepieceCards = sets.first?.cards.contains { card in
            card.id.contains("-op-copy") || cardCache[card.id] != nil
        } ?? false
        
        // If we already loaded cards for this binder this session and they're still there, skip
        if hasOnepieceCards && (onepieceCardsLoadedThisSession[selectedBinder] ?? false) {
            return
        }
        
        await loadOnePieceCardsFromSupabase()
        onepieceCardsLoadedThisSession[selectedBinder] = true
    }
    
    private func loadPokemonCardsFromSupabase() async {
        do {
            // Clean up any invalid quantities first
            try await pokemonPersistenceService.cleanupInvalidQuantities()
            
            // Clear existing Pokemon cards to prevent duplicates
            if selectedTCG == .pokemon {
                for setIndex in sets.indices {
                    // Only remove Pokemon cards (those added from Supabase)
                    sets[setIndex].cards.removeAll { card in
                        // Pokemon cards have specific ID patterns from our loading process
                        return card.id.contains("-copy") || cardCache[card.id] != nil
                    }
                }
                // Clear the card cache for Pokemon cards
                cardCache.removeAll()
            }
            
            // Get saved Pokemon cards for this user
            let userCards = try await pokemonPersistenceService.loadPokemonCards()
            
            guard !userCards.isEmpty else {
                return
            }
            
            // Get the unique Pokemon card IDs
            let cardIds = userCards.map { $0.cardId }
            
            // Fetch the actual Pokemon card data
            let pokemonCardDetails = try await pokemonPersistenceService.getPokemonCardDetails(for: cardIds)
            
            // Create a lookup dictionary for quick access
            let cardDetailsLookup = Dictionary(uniqueKeysWithValues: pokemonCardDetails.map { ($0.id, $0) })
            
            // Convert to OnePieceCard format and add to binder (respecting quantities)
            for userCard in userCards {
                guard let pokemonCardDetail = cardDetailsLookup[userCard.cardId] else {
                    continue
                }
                
                // Convert to internal card format
                let onePieceCard = adaptPokemonCardToInternalFormat(pokemonCardDetail)
                
                // Add multiple copies based on quantity (only if qty > 0)
                if let firstSet = sets.first, userCard.qty > 0 {
                    for copyIndex in 1...userCard.qty {
                        let binderCardId = "\(firstSet.id)-\(pokemonCardDetail.name)-\(userCard.cardId)-copy\(copyIndex)"
                        addCardToSet(onePieceCard, setId: firstSet.id, binderCardId: binderCardId)
                    }
                }
            }
            
        } catch {
            // Silently handle the error
        }
    }
    
    private func loadYuGiOhCardsFromSupabase() async {
        do {
            // Clean up any invalid quantities first
            try await yugiohPersistenceService.cleanupInvalidQuantities()
            
            // Clear existing Yu-Gi-Oh! cards to prevent duplicates
            if selectedTCG == .yugioh {
                for setIndex in sets.indices {
                    // Only remove Yu-Gi-Oh! cards (those added from Supabase)
                    sets[setIndex].cards.removeAll { card in
                        // Yu-Gi-Oh! cards have specific ID patterns from our loading process
                        return card.id.contains("-ygo-copy") || cardCache[card.id] != nil
                    }
                }
                // Clear the card cache for Yu-Gi-Oh! cards
                cardCache.removeAll()
            }
            
            // Get saved Yu-Gi-Oh! cards for this user
            let userCards = try await yugiohPersistenceService.loadYuGiOhCards()
            
            guard !userCards.isEmpty else {
                return
            }
            
            // Get the unique Yu-Gi-Oh! card IDs
            let cardIds = userCards.map { $0.cardId }
            
            // Fetch the actual Yu-Gi-Oh! card data
            let yugiohCardDetails = try await yugiohPersistenceService.getYuGiOhCardDetails(for: cardIds)
            
            // Create a lookup dictionary for quick access
            let cardDetailsLookup = Dictionary(uniqueKeysWithValues: yugiohCardDetails.map { ($0.id ?? "unknown", $0) })
            
            // Convert to OnePieceCard format and add to binder (respecting quantities)
            for userCard in userCards {
                guard let yugiohCardDetail = cardDetailsLookup[userCard.cardId] else {
                    continue
                }
                
                // Convert to internal card format
                let onePieceCard = adaptYuGiOhCardToInternalFormat(yugiohCardDetail)
                
                // Add multiple copies based on quantity (only if qty > 0)
                if let firstSet = sets.first, userCard.qty > 0 {
                    for copyIndex in 1...userCard.qty {
                        let binderCardId = "\(firstSet.id)-\(yugiohCardDetail.name)-\(userCard.cardId)-ygo-copy\(copyIndex)"
                        addCardToSet(onePieceCard, setId: firstSet.id, binderCardId: binderCardId)
                    }
                }
            }
            
        } catch {
            // Silently handle the error
        }
    }
    
    private func loadOnePieceCardsFromSupabase() async {
        do {
            // Clean up any invalid quantities first
            try await onepiecePersistenceService.cleanupInvalidQuantities()
            
            // Clear existing One Piece cards to prevent duplicates
            if selectedTCG == .onePiece {
                for setIndex in sets.indices {
                    // Only remove One Piece cards (those added from Supabase)
                    sets[setIndex].cards.removeAll { card in
                        // One Piece cards have specific ID patterns from our loading process
                        return card.id.contains("-op-copy") || cardCache[card.id] != nil
                    }
                }
                // Clear the card cache for One Piece cards
                cardCache.removeAll()
            }
            
            // Get saved One Piece cards for this user
            let userCards = try await onepiecePersistenceService.loadOnePieceCards()
            
            guard !userCards.isEmpty else {
                return
            }
            
            // Get the unique One Piece card IDs
            let cardIds = userCards.map { $0.cardId }
            
            // Fetch the actual One Piece card data
            let onepieceCardDetails = try await onepiecePersistenceService.getOnePieceCardDetails(for: cardIds)
            
            // Create a lookup dictionary for quick access
            let cardDetailsLookup = Dictionary(uniqueKeysWithValues: onepieceCardDetails.map { ($0.id ?? "unknown", $0) })
            
            // Add to binder (respecting quantities)
            for userCard in userCards {
                guard let onepieceCardDetail = cardDetailsLookup[userCard.cardId] else {
                    continue
                }
                
                // Add multiple copies based on quantity (only if qty > 0)
                if let firstSet = sets.first, userCard.qty > 0 {
                    for copyIndex in 1...userCard.qty {
                        let binderCardId = "\(firstSet.id)-\(onepieceCardDetail.name)-\(userCard.cardId)-op-copy\(copyIndex)"
                        addCardToSet(onepieceCardDetail, setId: firstSet.id, binderCardId: binderCardId)
                    }
                }
            }
            
        } catch {
            // Silently handle the error
        }
    }
    
    private func adaptPokemonCardToInternalFormat(_ pokemonCard: PokemonCardResponse) -> OnePieceCard {
        
        return OnePieceCard(
            cardName: pokemonCard.name,
            rarity: pokemonCard.rarity,
            cardCost: nil,
            cardPower: pokemonCard.hp != nil ? String(pokemonCard.hp!) : nil,
            counterAmount: nil,
            cardColor: pokemonCard.types?.first,
            cardType: pokemonCard.types?.joined(separator: ", "),
            cardText: pokemonCard.abilities?.first?.text,
            setId: pokemonCard.set_id,
            cardSetId: pokemonCard.id,
            cardImage: pokemonCard.image_url,
            attribute: pokemonCard.subtypes?.joined(separator: ", "),
            inventoryPrice: pokemonCard.tcgplayer_market_price,
            marketPrice: pokemonCard.tcgplayer_market_price,
            setName: mapPokemonSetIdToDisplayName(pokemonCard.set_id),
            subTypes: pokemonCard.subtypes?.joined(separator: ", "),
            life: nil,
            dateScrapped: nil,
            cardImageId: pokemonCard.id,
            trigger: nil,
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
    
    private func adaptYuGiOhCardToInternalFormat(_ yugiohCard: YuGiOhCard) -> OnePieceCard {
        
        return OnePieceCard(
            cardName: yugiohCard.name,
            rarity: nil,
            cardCost: nil,
            cardPower: nil,
            counterAmount: nil,
            cardColor: nil,
            cardType: yugiohCard.type,
            cardText: yugiohCard.description,
            setId: yugiohCard.frameType,
            cardSetId: yugiohCard.id ?? "unknown",
            cardImage: yugiohCard.imageUrl,
            attribute: yugiohCard.frameType,
            inventoryPrice: nil,
            marketPrice: nil,
            setName: yugiohCard.frameType,
            subTypes: yugiohCard.type,
            life: nil,
            dateScrapped: nil,
            cardImageId: yugiohCard.id ?? "unknown",
            trigger: nil,
            databaseUUID: yugiohCard.id ?? "unknown"  // Store the actual database UUID
        )
    }
    
    @MainActor
    private func addCardToSet(_ onePieceCard: OnePieceCard, setId: String, binderCardId: String) {
        guard let setIndex = sets.firstIndex(where: { $0.id == setId }) else {
            return
        }
        
        let url = URL(string: onePieceCard.cardImage ?? "about:blank") ?? URL(string: "about:blank")!
        
        // Cache the full API data
        cardCache[binderCardId] = onePieceCard
        
        // Create the TCGCard for the binder
        let tcgCard = TCGCard(
            id: binderCardId,
            name: onePieceCard.name,
            imageURL: url,
            setID: setId,
            rarity: onePieceCard.rarity,
            cardCost: onePieceCard.cardCost,
            cardPower: onePieceCard.cardPower,
            counterAmount: onePieceCard.counterAmount,
            cardColor: onePieceCard.cardColor,
            cardType: onePieceCard.cardType,
            cardText: onePieceCard.cardText,
            attribute: onePieceCard.attribute,
            inventoryPrice: onePieceCard.inventoryPrice,
            marketPrice: onePieceCard.marketPrice,
            subTypes: onePieceCard.subTypes,
            life: onePieceCard.life,
            trigger: onePieceCard.trigger
        )
        
        sets[setIndex].cards.append(tcgCard)
    }
    
    // MARK: - Remove Pokemon Card
    
    func removePokemonCard(_ card: TCGCard) {
        guard selectedTCG == .pokemon else {
            return
        }
        
        // Find and remove the card from the set
        guard let setIndex = sets.firstIndex(where: { $0.id == card.setID }),
              let cardIndex = sets[setIndex].cards.firstIndex(where: { $0.id == card.id }) else {
            return
        }
        
        // Get the original Pokemon card ID for Supabase
        let pokemonCardId = cardCache[card.id]?.cardSetId ?? card.id
        
        // Remove from local binder
        sets[setIndex].cards.remove(at: cardIndex)
        cardCache.removeValue(forKey: card.id)
        
        // Update Supabase quantity
        Task {
            do {
                try await pokemonPersistenceService.removePokemonCard(cardId: pokemonCardId)
            } catch {
                // Silently handle the error
            }
        }
        
        // Persist local changes
        persist()
    }
    
    // MARK: - Remove Yu-Gi-Oh! Card
    
    func removeYuGiOhCard(_ card: TCGCard) {
        guard selectedTCG == .yugioh else {
            return
        }
        
        // Find and remove the card from the set
        guard let setIndex = sets.firstIndex(where: { $0.id == card.setID }),
              let cardIndex = sets[setIndex].cards.firstIndex(where: { $0.id == card.id }) else {
            return
        }
        
        // Get the original Yu-Gi-Oh! card ID for Supabase
        let yugiohCardId = cardCache[card.id]?.cardSetId ?? card.id
        
        // Remove from local binder
        sets[setIndex].cards.remove(at: cardIndex)
        cardCache.removeValue(forKey: card.id)
        
        // Update Supabase quantity
        Task {
            do {
                try await yugiohPersistenceService.removeYuGiOhCard(cardId: yugiohCardId)
            } catch {
                // Silently handle the error
            }
        }
        
        // Persist local changes
        persist()
    }
    
    // MARK: - Remove One Piece Card
    
    func removeOnePieceCard(_ card: TCGCard) {
        guard selectedTCG == .onePiece else {
            return
        }
        
        // Find and remove the card from the set
        guard let setIndex = sets.firstIndex(where: { $0.id == card.setID }),
              let cardIndex = sets[setIndex].cards.firstIndex(where: { $0.id == card.id }) else {
            return
        }
        
        // Get the original One Piece card ID for Supabase
        let onepieceCardId = cardCache[card.id]?.cardSetId ?? cardCache[card.id]?.id ?? card.id
        
        // Remove from local binder
        sets[setIndex].cards.remove(at: cardIndex)
        cardCache.removeValue(forKey: card.id)
        
        // Update Supabase quantity
        Task {
            do {
                try await onepiecePersistenceService.removeOnePieceCard(cardId: onepieceCardId)
            } catch {
                // Silently handle the error
            }
        }
        
        // Persist local changes
        persist()
    }
    
    // MARK: - Binder Name Management
    
    func updateBinderName(_ newName: String) {
        binderName = newName.isEmpty ? "My \(selectedTCG.displayName) Binder" : newName
        persist()
    }
    
    // MARK: - Binder Management
    
    
    private func saveCurrentBinderData() {
        // Filter out database cards from sets before saving (they should not be persisted per-binder)
        var setsToSave = sets
        if selectedTCG == .onePiece {
            for index in setsToSave.indices {
                setsToSave[index].cards.removeAll { card in
                    card.id.contains("-op-copy") || cardCache[card.id] != nil
                }
            }
        }
        
        if selectedTCG == .pokemon {
            for index in setsToSave.indices {
                setsToSave[index].cards.removeAll { card in
                    card.id.contains("-copy") || cardCache[card.id] != nil
                }
            }
        }
        
        if selectedTCG == .yugioh {
            for index in setsToSave.indices {
                setsToSave[index].cards.removeAll { card in
                    card.id.contains("-ygo-copy") || cardCache[card.id] != nil
                }
            }
        }
        
        // Filter out database cards from cardCache before saving
        var cacheToSave = cardCache
        if selectedTCG == .onePiece || selectedTCG == .pokemon || selectedTCG == .yugioh {
            cacheToSave.removeAll()
        }
        
        let currentData = BinderData(
            sets: setsToSave,
            currentSetID: currentSetID,
            spreadIndexBySet: spreadIndexBySet,
            binderName: binderName,
            selectedTCG: selectedTCG,
            cardCache: cacheToSave
        )
        
        binderData[selectedBinder] = currentData
        
        // Also persist to UserDefaults
        if let encoded = try? JSONEncoder().encode(currentData) {
            UserDefaults.standard.set(encoded, forKey: binderDataKey)
        }
    }
    
    private func loadBinderData() {
        // First try to load from memory
        if let data = binderData[selectedBinder] {
            applyBinderData(data)
            return
        }
        
        // Then try to load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: binderDataKey),
           let decoded = try? JSONDecoder().decode(BinderData.self, from: data) {
            binderData[selectedBinder] = decoded
            applyBinderData(decoded)
            return
        }
        
        // If no data exists, create default data
        createDefaultBinderData()
    }
    
    private func applyBinderData(_ data: BinderData) {
        sets = data.sets
        currentSetID = data.currentSetID
        spreadIndexBySet = data.spreadIndexBySet
        binderName = data.binderName.isEmpty ? selectedBinder.defaultName : data.binderName
        selectedTCG = data.selectedTCG
        cardCache = data.cardCache
    }
    
    private func createDefaultBinderData() {
        sets = selectedTCG.defaultSets
        currentSetID = sets.first?.id
        spreadIndexBySet = [:]
        binderName = selectedBinder.defaultName
        cardCache = [:]
        
        // Save this default data
        saveCurrentBinderData()
    }
    
    // MARK: - TCG Management
    
    func switchTCG(to newTCG: TCGType) {
        guard newTCG != selectedTCG else { 
            return 
        }
        
        // Save current state before switching
        saveCurrentBinderData()
        
        // Switch to new TCG
        selectedTCG = newTCG
        
        // Reset sets to match the new TCG
        sets = newTCG.defaultSets
        currentSetID = sets.first?.id
        query = ""
        searchResults = []
        spreadIndexBySet = [:]
        cardCache = [:]
        
        // Update binder name to include new TCG if it's still default
        if binderName == selectedBinder.defaultName {
            binderName = selectedBinder.defaultName
        }
        
        // Reset loading flags for this binder when switching
        onepieceCardsLoadedThisSession[selectedBinder] = false
        pokemonCardsLoadedThisSession[selectedBinder] = false
        yugiohCardsLoadedThisSession[selectedBinder] = false
        
        // Save the updated state
        saveCurrentBinderData()
        
    }
    
    // MARK: - Persistence

    private func loadPersistedInitial() {
        let ud = UserDefaults.standard
        
        // Load selected binder first
        if let binderRawValue = ud.string(forKey: selectedBinderKey),
           let binderType = BinderType(rawValue: binderRawValue) {
            self.selectedBinder = binderType
        }
        
        // Load data for the selected binder
        loadBinderData()
    }


    private func persist() {
        // Save current binder data whenever anything changes
        saveCurrentBinderData()
        
        // Also persist the selected binder
        UserDefaults.standard.set(selectedBinder.rawValue, forKey: selectedBinderKey)
    }

    // MARK: - Data Management
    
    @Published var showingClearDataConfirmation = false
    
    func clearAllData() {
        // Show confirmation dialog
        showingClearDataConfirmation = true
    }
    
    func confirmClearAllData() async {
        // Clear from Supabase first
        await clearAllDataFromSupabase()
        
        // Clear all local data silently
        clearAllDataSilently()
        
        // Reset in-memory data
        binderData = [:]
        userBinders = []
        selectedUserBinder = nil
        
        // Reset current state to defaults
        selectedBinder = .black
        sets = []
        currentSetID = nil
        query = ""
        searchResults = []
        spreadIndexBySet = [:]
        cardCache = [:]
        binderName = selectedBinder.defaultName
        
        // Create default data for current binder
        createDefaultBinderData()
        
        print("✅ All user data cleared successfully")
    }
    
    private func clearAllDataFromSupabase() async {
        print("🧹 Clearing all user data from Supabase...")
        
        do {
            // Clear all Pokemon cards
            try await pokemonPersistenceService.clearAllPokemonCards()
        } catch {
            print("⚠️ Failed to clear Pokemon cards: \(error)")
        }
        
        do {
            // Clear all Yu-Gi-Oh! cards
            try await yugiohPersistenceService.clearAllYuGiOhCards()
        } catch {
            print("⚠️ Failed to clear Yu-Gi-Oh! cards: \(error)")
        }
        
        do {
            // Clear all One Piece cards
            try await onepiecePersistenceService.clearAllOnePieceCards()
        } catch {
            print("⚠️ Failed to clear One Piece cards: \(error)")
        }
        
        do {
            // Clear all binder cards
            try await binderCardService.clearAllBinderCards()
        } catch {
            print("⚠️ Failed to clear binder cards: \(error)")
        }
        
        do {
            // Clear all binders
            try await userBinderService.clearAllBinders()
        } catch {
            print("⚠️ Failed to clear binders: \(error)")
        }
        
        print("✅ Supabase data cleared")
    }
    
    private func clearAllDataSilently() {
        let ud = UserDefaults.standard
        
        // Clear data for all binder types
        for binderType in BinderType.allCases {
            let binderDataKey = "binder.data.\(binderType.rawValue)"
            ud.removeObject(forKey: binderDataKey)
        }
        
        // Clear old TCG-specific keys (for migration from old system)
        for tcgType in TCGType.allCases {
            let spreadsKey = "binder.spreadIndexBySet.\(tcgType.rawValue)"
            let setsKey = "binder.sets.\(tcgType.rawValue)"
            let cardCacheKey = "binder.cardCache.\(tcgType.rawValue)"
            let binderNameKey = "binder.binderName.\(tcgType.rawValue)"
            
            ud.removeObject(forKey: spreadsKey)
            ud.removeObject(forKey: setsKey)
            ud.removeObject(forKey: cardCacheKey)
            ud.removeObject(forKey: binderNameKey)
        }
        
        // Clear selected TCG and binder
        ud.removeObject(forKey: selectedTCGKey)
        ud.removeObject(forKey: selectedBinderKey)
    }

    private func loadMockSets() {
        // Only load mock sets if no persisted data was found
        if sets.isEmpty {
            self.sets = selectedTCG.defaultSets
        }
    }
    
    // MARK: - Binder Management
    
    func getCurrentBinderNumber() -> Int {
        // Return the selected user binder's assigned value, or 1 as default
        return Int(selectedUserBinder?.assigned_value ?? 1)
    }
    
    func loadUserBinders() async {
        do {
            let binders = try await userBinderService.getUserBinders()
            await MainActor.run {
                userBinders = binders.sorted { (binder1: UserBinder, binder2: UserBinder) in
                    Int(binder1.assigned_value) < Int(binder2.assigned_value)
                }
                
                // Check if currently selected binder still exists
                if let currentBinder = selectedUserBinder,
                   let binderId = currentBinder.id,
                   !userBinders.contains(where: { $0.id == binderId }) {
                    // Currently selected binder was deleted, clear selection
                    selectedUserBinder = nil
                    binderName = "My TCG Binder"
                }
                
                // Select the first binder if none is selected and binders exist
                if selectedUserBinder == nil && !userBinders.isEmpty {
                    selectedUserBinder = userBinders.first
                    binderName = selectedUserBinder?.name ?? "My TCG Binder"
                }
            }
        } catch {
            print("❌ Failed to load user binders: \(error)")
        }
    }
    
    func selectUserBinder(_ binder: UserBinder) {
        selectedUserBinder = binder
        binderName = binder.name
        
        // Set the TCG type based on the binder's game
        if let gameString = binder.game, let tcgType = TCGType(rawValue: gameString) {
            selectedTCG = tcgType
        }
        
        // Clear the old binder's cards from UI when switching binders
        clearCurrentBinderCards()
        
        // Clear session cache when switching binders to ensure fresh loads
        clearSessionCache()
        
        // Don't auto-load cards - only load when user explicitly opens the binder
    }
    
    // MARK: - Open Binder (Explicit User Action)
    
    func openUserBinder(_ binder: UserBinder) {
        // First select the binder
        selectUserBinder(binder)
        
        // Then load cards for this specific binder
        Task {
            await loadCardsIfNeeded()
        }
    }
    
    // MARK: - Create New Binder
    
    @MainActor
    func createNewBinder(name: String, color: Color, game: TCGType) async throws {
        // Create the binder in Supabase with the specified color and game
        let binderId = try await userBinderService.createBinder(
            name: name,
            color: color,
            game: game
        )
        
        // Reload user binders to show the new one
        await loadUserBinders()
        
        print("✅ Created new binder: \(name) with color: \(UserBinder.colorToString(color)), game: \(game.rawValue), and ID: \(binderId)")
    }
    
    // MARK: - Update Binder Color
    
    @MainActor
    func updateBinderColor(_ binder: UserBinder, newColor: Color) async throws {
        guard let binderId = binder.id else {
            throw NSError(domain: "BinderError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Binder ID is missing"])
        }
        
        // Update color in Supabase
        try await userBinderService.updateBinderColor(binderId: binderId, newColor: newColor)
        
        // Reload user binders to reflect the change
        await loadUserBinders()
        
        print("✅ Updated binder color for: \(binder.name)")
    }
    
    // MARK: - Delete Binder
    
    @MainActor
    func deleteCurrentBinder() async throws {
        guard let selectedBinder = selectedUserBinder,
              let binderId = selectedBinder.id else {
            throw NSError(domain: "BinderError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No binder selected or missing binder ID"])
        }
        
        print("🗑️ Deleting binder: \(selectedBinder.name)")
        
        // Delete from Supabase
        try await userBinderService.deleteBinder(binderId: binderId)
        
        // Clear current binder selection immediately
        selectedUserBinder = nil
        binderName = "My TCG Binder"
        
        // Clear any cards from the current view
        sets = []
        currentSetID = nil
        
        // Reload user binders to reflect the change
        await loadUserBinders()
        
        print("✅ Deleted binder: \(selectedBinder.name)")
    }
    
    // MARK: - Universal Binder Card Removal
    
    /// Remove a card from the current binder (works for all TCG types)
    func removeCardFromCurrentBinder(_ card: TCGCard) {
        guard let selectedBinder = selectedUserBinder else {
            print("❌ No selected binder to remove card from")
            return
        }
        
        // Ensure the binder has a valid ID
        guard let binderId = selectedBinder.id, !binderId.isEmpty else {
            print("❌ Binder ID is nil or empty, cannot remove card")
            return
        }
        
        // Ensure the card has a valid ID
        let cardId = card.id
        guard !cardId.isEmpty else {
            print("❌ Card ID is empty, cannot remove from binder")
            return
        }
        
        Task {
            do {
                try await binderCardService.removeCardFromBinder(
                    binderId: binderId,
                    cardId: cardId,
                    cardType: selectedTCG
                )
                
                // Refresh the binder to show updated cards
                await MainActor.run {
                    Task {
                        await loadCardsIfNeeded(forceRefresh: true)
                    }
                }
                
            } catch {
                print("❌ Failed to remove card from binder: \(error)")
                // Could show an alert here in the future
            }
        }
    }
    
    // MARK: - Card Notes Management
    
    /// Load user notes for a specific card in a binder
    func loadCardNotes(cardId: String, binderId: String) async throws -> String {
        return try await binderCardService.loadCardNotes(cardId: cardId, binderId: binderId)
    }
    
    /// Save user notes for a specific card in a binder
    func saveCardNotes(cardId: String, binderId: String, notes: String) async throws {
        try await binderCardService.saveCardNotes(cardId: cardId, binderId: binderId, notes: notes)
    }
}
