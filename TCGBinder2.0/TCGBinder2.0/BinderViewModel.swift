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
    
    // Separate data for each binder type
    private var binderData: [BinderType: BinderData] = [:]

    private let selectedTCGKey = "binder.selectedTCG"
    private let selectedBinderKey = "binder.selectedBinder"
    
    // Binder-specific storage keys
    private var binderDataKey: String { "binder.data.\(selectedBinder.rawValue)" }
    
    // Separate cache for full API card data
    private var cardCache: [String: OnePieceCard] = [:]

    init() {
        print("🚀 Initializing BinderViewModel...")
        
        // Check if this is a fresh install or if we want to clear data
        let ud = UserDefaults.standard
        let hasLaunchedBefore = ud.bool(forKey: "hasLaunchedBefore")
        
        if !hasLaunchedBefore {
            print("🆕 First launch detected - clearing any existing data")
            // Clear any residual data from previous installs
            clearAllDataSilently()
            ud.set(true, forKey: "hasLaunchedBefore")
        }
        
        loadPersistedInitial()
        loadMockSets()
        
        if currentSetID == nil { 
            currentSetID = sets.first?.id 
            print("🎯 Set current set to: \(currentSetID ?? "none")")
        }
        
        print("✅ BinderViewModel initialized with \(sets.count) sets")
        print("🎮 Selected TCG: \(selectedTCG.displayName)")
        for set in sets {
            print("  - \(set.name): \(set.cards.count) cards")
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
            print("❌ Could not find set with ID: \(setID)")
            return 
        }
        
        let cardID = "\(setID)-\(sets[setIndex].cards.count + 1)"
        let url = URL(string: onePieceCard.image ?? "about:blank") ?? URL(string: "about:blank")!
        
        print("🎴 Adding card: \(onePieceCard.name) with ID: \(cardID)")
        
        // Cache the full API data separately
        cardCache[cardID] = onePieceCard
        print("💾 Cached API data for \(cardID)")
        
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
        print("📚 Added card to set \(setID). Set now has \(sets[setIndex].cards.count) cards")
        
        // Navigate to the page containing the new card
        let cardIndex = sets[setIndex].cards.count - 1
        let pageIndex = cardIndex / 9
        setPageIndex(pageIndex, for: setID)
        
        // Persist the changes
        persist()
    }

    // MARK: - Card Cache Access
    
    func getCachedCardData(for cardID: String) -> OnePieceCard? {
        return cardCache[cardID]
    }
    
    // MARK: - Binder Name Management
    
    func updateBinderName(_ newName: String) {
        binderName = newName.isEmpty ? "My \(selectedTCG.displayName) Binder" : newName
        persist()
    }
    
    // MARK: - Binder Management
    
    func switchBinder(to newBinder: BinderType) {
        guard newBinder != selectedBinder else { 
            print("🔄 No switch needed - already on \(newBinder.displayName)")
            return 
        }
        
        print("🔄 Starting switch from \(selectedBinder.displayName) to \(newBinder.displayName)")
        
        // Save current binder data
        saveCurrentBinderData()
        
        // Switch to new binder
        selectedBinder = newBinder
        
        // Load data for new binder
        loadBinderData()
        
        // Persist the selected binder
        UserDefaults.standard.set(selectedBinder.rawValue, forKey: selectedBinderKey)
        
        print("✅ Binder switch complete to \(newBinder.displayName)")
        print("📊 New state: \(sets.count) sets, currentSetID: \(currentSetID ?? "none")")
        print("📛 Binder name: \(binderName)")
    }
    
    private func saveCurrentBinderData() {
        let currentData = BinderData(
            sets: sets,
            currentSetID: currentSetID,
            spreadIndexBySet: spreadIndexBySet,
            binderName: binderName,
            selectedTCG: selectedTCG,
            cardCache: cardCache
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
            print("🔄 No switch needed - already on \(newTCG.displayName)")
            return 
        }
        
        print("🔄 Starting TCG switch from \(selectedTCG.displayName) to \(newTCG.displayName) for binder: \(selectedBinder.displayName)")
        
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
        
        // Save the updated state
        saveCurrentBinderData()
        
        print("✅ TCG switch complete to \(newTCG.displayName)")
        print("📊 New state: \(sets.count) sets, currentSetID: \(currentSetID ?? "none")")
        print("📛 Binder name: \(binderName)")
    }
    
    // MARK: - Persistence

    private func loadPersistedInitial() {
        let ud = UserDefaults.standard
        print("🔄 Starting initial persistence load...")
        
        // Load selected binder first
        if let binderRawValue = ud.string(forKey: selectedBinderKey),
           let binderType = BinderType(rawValue: binderRawValue) {
            self.selectedBinder = binderType
            print("✅ Loaded selected binder: \(binderType.displayName)")
        } else {
            print("ℹ️ No saved binder found, using default: \(selectedBinder.displayName)")
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
        print("🧹 Clearing all persisted data...")
        
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
        
        print("✅ All data cleared and reset to empty state")
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
            print("📦 Loading empty sets for \(selectedTCG.displayName)...")
            self.sets = selectedTCG.defaultSets
            print("✅ Created \(sets.count) empty sets for \(selectedTCG.displayName)")
        } else {
            print("ℹ️ Skipping mock data - using persisted sets for \(selectedTCG.displayName)")
        }
    }
}
