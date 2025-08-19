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
    @Published var selectedBinder: BinderType = .green
    
    // Pokemon persistence service
    private let pokemonPersistenceService = PokemonCardPersistenceService()
    
    // Track if Pokemon cards have been loaded this session (per binder)
    private var pokemonCardsLoadedThisSession: [BinderType: Bool] = [:]
    
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
        
        sets[setIndex].cards.append(newCard)
        
        // Navigate to the page containing the new card
        let cardIndex = sets[setIndex].cards.count - 1
        let pageIndex = cardIndex / 9
        setPageIndex(pageIndex, for: setID)
        
        // If this is a Pokemon card, also save to Supabase
        if selectedTCG == .pokemon {
            Task {
                do {
                    try await pokemonPersistenceService.addPokemonCard(
                        cardId: onePieceCard.cardSetId ?? onePieceCard.id ?? cardID
                    )
                } catch {
                    // Silently handle the error
                }
            }
        }
        
        // Persist the changes
        persist()
    }

    // MARK: - Card Cache Access
    
    func getCachedCardData(for cardID: String) -> OnePieceCard? {
        return cardCache[cardID]
    }
    
    // MARK: - Pokemon Card Persistence
    
    func loadPokemonCardsIfNeeded() async {
        // Only load if we're in Pokemon mode
        guard selectedTCG == .pokemon else {
            return
        }
        
        // Check if we already have Pokemon cards loaded for this binder (prevent duplicates)
        let hasPokemonCards = sets.first?.cards.contains { card in
            card.id.contains("-copy") || cardCache[card.id] != nil
        } ?? false
        
        // If we already loaded cards for this binder this session and they're still there, skip
        if hasPokemonCards && (pokemonCardsLoadedThisSession[selectedBinder] ?? false) {
            return
        }
        
        await loadPokemonCardsFromSupabase()
        pokemonCardsLoadedThisSession[selectedBinder] = true
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
                
                // Convert to OnePieceCard format
                let onePieceCard = convertPokemonToOnePieceCard(pokemonCardDetail)
                
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
    
    private func convertPokemonToOnePieceCard(_ pokemonCard: PokemonCardResponse) -> OnePieceCard {
        
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
            setName: pokemonCard.set_id,
            subTypes: pokemonCard.subtypes?.joined(separator: ", "),
            life: nil,
            dateScrapped: nil,
            cardImageId: pokemonCard.id,
            trigger: nil
        )
    }
    
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
    
    // MARK: - Binder Name Management
    
    func updateBinderName(_ newName: String) {
        binderName = newName.isEmpty ? "My \(selectedTCG.displayName) Binder" : newName
        persist()
    }
    
    // MARK: - Binder Management
    
    func switchBinder(to newBinder: BinderType) {
        guard newBinder != selectedBinder else { 
            return 
        }
        
        // Save current binder data (this will filter out Pokemon cards)
        saveCurrentBinderData()
        
        // Clear Pokemon cards from current session since they don't belong to binders
        if selectedTCG == .pokemon {
            for setIndex in sets.indices {
                sets[setIndex].cards.removeAll { card in
                    card.id.contains("-copy") || cardCache[card.id] != nil
                }
            }
            let keysToRemove = cardCache.keys.filter { key in
                key.contains("-copy")
            }
            for key in keysToRemove {
                cardCache.removeValue(forKey: key)
            }
        }
        
        // Switch to new binder
        selectedBinder = newBinder
        
        // Load data for new binder
        loadBinderData()
        
        // If new binder is in Pokemon mode, reload Pokemon cards
        if selectedTCG == .pokemon {
            pokemonCardsLoadedThisSession[selectedBinder] = false
            Task {
                await loadPokemonCardsIfNeeded()
            }
        }
        
        // Persist the selected binder
        UserDefaults.standard.set(selectedBinder.rawValue, forKey: selectedBinderKey)
    }
    
    private func saveCurrentBinderData() {
        // Filter out Pokemon cards from sets before saving (they should not be persisted per-binder)
        var setsToSave = sets
        if selectedTCG == .pokemon {
            for index in setsToSave.indices {
                setsToSave[index].cards.removeAll { card in
                    card.id.contains("-copy") || cardCache[card.id] != nil
                }
            }
        }
        
        // Filter out Pokemon cards from cardCache before saving
        var cacheToSave = cardCache
        if selectedTCG == .pokemon {
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
        
        // Reset Pokemon loading flag for this binder when switching to OR FROM Pokemon
        pokemonCardsLoadedThisSession[selectedBinder] = false
        
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
    
    func clearAllData() {
        // Clear all data silently
        clearAllDataSilently()
        
        // Reset in-memory data
        binderData = [:]
        
        // Reset current state to defaults
        selectedBinder = .green
        sets = []
        currentSetID = nil
        query = ""
        searchResults = []
        spreadIndexBySet = [:]
        cardCache = [:]
        binderName = selectedBinder.defaultName
        
        // Create default data for current binder
        createDefaultBinderData()
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
}
