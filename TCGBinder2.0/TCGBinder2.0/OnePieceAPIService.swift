import Foundation

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
    }
    
    // Identifiable requirement - use unique combination to handle parallel arts
    var id: String { 
        if let setId = cardSetId, let imageId = cardImageId {
            return "\(setId)-\(imageId)"  // This will be unique for parallel arts
        } else if let setId = cardSetId {
            return setId
        } else {
            return UUID().uuidString
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

struct OnePieceSet: Codable, Identifiable {
    let id: String
    let name: String
    let cards: [OnePieceCard]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, cards
    }
}

// MARK: - Search Progress Tracking
struct SearchProgress {
    var currentSetIndex = 0
    var setsToSearch: [String] = []
    
    mutating func reset() {
        currentSetIndex = 0
        setsToSearch = []
    }
    
    mutating func setupSets(setId: String?) {
        // Search in descending order (newest sets first), only 2 sets at a time
        if let setId = setId {
            setsToSearch = [setId]
        } else {
            setsToSearch = ["OP-11", "OP-10"]  // Start with newest 2 sets - using correct API format
        }
    }
    
    mutating func loadNextTwoSets() {
        // Add the next 2 sets when loading more - using correct API format
        let allSetsDescending = ["OP-11", "OP-10", "OP-09", "OP-08", "OP-07", "OP-06", "OP-05", "OP-04", "OP-03", "OP-02", "OP-01"]
        let currentCount = setsToSearch.count
        
        if currentCount < allSetsDescending.count {
            let nextSets = Array(allSetsDescending.dropFirst(currentCount).prefix(2))
            setsToSearch.append(contentsOf: nextSets)
        }
    }
}

// MARK: - API Service
@MainActor
class OnePieceAPIService: ObservableObject, TCGAPIService {
    @Published var searchResults: [OnePieceCard] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var availableSets: [(id: String, name: String)] = []
    @Published var canLoadMore = false
    
    private let baseURL = "https://optcgapi.com/api"
    private var searchTask: Task<Void, Never>?
    private var currentQuery = ""
    private var currentSetId: String?
    private var searchProgress = SearchProgress()
    private var currentSearchId = UUID()
    private var cachedSets: [String: [OnePieceCard]] = [:]  // Cache fetched sets
    private var consecutiveEmptyBatches = 0  // Track empty batches to prevent infinite loops
    
    func getAvailableSets() -> [(id: String, name: String)] {
        return availableSets
    }
    
    func loadAllSets() async {
        print("🔄 Loading all sets from API...")
        do {
            let urlString = "\(baseURL)/allSets/"
            print("🌐 API Call: \(urlString)")
            
            guard let url = URL(string: urlString) else {
                print("❌ Invalid URL: \(urlString)")
                return
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                return
            }
            
            print("📡 HTTP Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // Try to parse as array of simple objects
                let jsonString = String(data: data, encoding: .utf8) ?? "Unable to decode"
                print("📄 Raw response: \(jsonString)")
                
                // Use hardcoded sets in descending order (newest first) - only for set picker
                availableSets = [
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
                print("✅ Using predefined sets: \(availableSets.count) sets")
            } else {
                print("❌ HTTP Error: \(httpResponse.statusCode)")
                print("📄 Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            }
        } catch {
            print("❌ Error loading sets: \(error)")
        }
    }
    
    func searchCards(query: String, setId: String?) {
        // Cancel previous search task
        searchTask?.cancel()
        
        // Generate new search ID for this search session
        let searchId = UUID()
        currentSearchId = searchId
        
        // Store current search parameters
        currentQuery = query
        currentSetId = setId
        
        // Reset search progress for new search
        searchProgress.reset()
        searchProgress.setupSets(setId: setId)
        consecutiveEmptyBatches = 0
        
        // Clear existing results for new search
        searchResults = []
        canLoadMore = false
        
        // Debounced search with delay
        searchTask = Task { [weak self] in
            // Wait 500ms to debounce rapid typing
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Check if this search was cancelled or superseded
            guard !Task.isCancelled, await self?.currentSearchId == searchId else { 
                print("🚫 Search cancelled or superseded")
                return 
            }
            
            await self?.performInitialSearch(query: query, setId: setId, searchId: searchId)
        }
    }
    
    func loadMoreResults() {
        guard !currentQuery.isEmpty && canLoadMore && !isLoadingMore else { return }
        
        let searchId = currentSearchId  // Capture current search ID
        
        Task { [weak self] in
            await self?.setIsLoadingMore(true)
            await self?.performLoadMoreSearch(searchId: searchId)
            await self?.setIsLoadingMore(false)
        }
    }
    
    private func setIsLoadingMore(_ loading: Bool) {
        isLoadingMore = loading
    }
    
    private func performInitialSearch(query: String, setId: String? = nil, searchId: UUID) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            canLoadMore = false
            return
        }
        
        // Check if this search is still current
        guard currentSearchId == searchId else {
            print("🚫 Initial search abandoned - newer search started")
            return
        }
        
        print("🔍 Initial search for: '\(query)' in set: \(setId ?? "newest sets first")")
        
        isLoading = true
        errorMessage = nil
        
        // Start with just first set and limited cards to avoid rate limiting
        await searchNextBatch(query: query, initialSearch: true, searchId: searchId)
        
        isLoading = false
    }
    
    private func performLoadMoreSearch(searchId: UUID) async {
        guard !currentQuery.isEmpty else { return }
        
        // Check if this search is still current
        guard currentSearchId == searchId else {
            print("🚫 Load more search abandoned - newer search started")
            return
        }
        
        print("🔍 Loading more results for: '\(currentQuery)'")
        await searchNextBatch(query: currentQuery, initialSearch: false, searchId: searchId)
    }
    
    private func searchNextBatch(query: String, initialSearch: Bool, searchId: UUID) async {
        var newCards: [OnePieceCard] = []
        let maxResultsPerBatch = initialSearch ? 10 : 20  // Can be higher since we're not making individual API calls
        let setsToProcess = initialSearch ? 1 : 2  // Process 1-2 sets per batch
        var setsProcessed = 0
        
        while searchProgress.currentSetIndex < searchProgress.setsToSearch.count && 
              newCards.count < maxResultsPerBatch && 
              setsProcessed < setsToProcess {
            
            // Check if search is still current
            guard currentSearchId == searchId else {
                print("🚫 Search batch abandoned - newer search started")
                return
            }
            
            let setCode = searchProgress.setsToSearch[searchProgress.currentSetIndex]
            print("🎯 Searching in set: \(setCode)")
            
            // Fetch entire set if not cached
            let setCards: [OnePieceCard]
            if let cached = cachedSets[setCode] {
                print("📦 Using cached data for \(setCode) (\(cached.count) cards)")
                setCards = cached
            } else {
                print("🌐 Fetching all cards for set: \(setCode)")
                do {
                    setCards = try await loadCardsFromSet(setId: setCode)
                    cachedSets[setCode] = setCards  // Cache the results
                    print("✅ Cached \(setCards.count) cards for \(setCode)")
                } catch {
                    print("❌ Failed to load set \(setCode): \(error)")
                    searchProgress.currentSetIndex += 1
                    setsProcessed += 1
                    consecutiveEmptyBatches += 1
                    continue
                }
                
                // Check if search is still current after network request
                guard currentSearchId == searchId else {
                    print("🚫 Search abandoned during set fetch")
                    return
                }
            }
            
            // Filter cards locally
            let matchingCards = setCards.filter { card in
                card.name.lowercased().contains(query.lowercased())
            }
            
            if !matchingCards.isEmpty {
                print("✅ Found \(matchingCards.count) matches in \(setCode):")
                for card in matchingCards.prefix(maxResultsPerBatch - newCards.count) {
                    newCards.append(card)
                    print("  - \(card.name) (\(card.cardSetId ?? "unknown"))")
                }
                consecutiveEmptyBatches = 0
            } else {
                print("🔍 No matches in \(setCode)")
                consecutiveEmptyBatches += 1
            }
            
            searchProgress.currentSetIndex += 1
            setsProcessed += 1
        }
        
        // Add new results to existing results
        searchResults.append(contentsOf: newCards)
        
        // Determine if more results are available
        let hasMoreSetsToAdd = searchProgress.setsToSearch.count < 11  // Max 11 sets (OP01-OP11)
        let hasMoreCardsInCurrentSets = searchProgress.currentSetIndex < searchProgress.setsToSearch.count
        
        // Stop if we have 3 consecutive empty sets or finished all sets
        let shouldStop = consecutiveEmptyBatches >= 3 || (!hasMoreCardsInCurrentSets && !hasMoreSetsToAdd)
        
        if shouldStop {
            canLoadMore = false
            print("🏁 Search completed: \(searchResults.count) total results")
        } else {
            // If we've finished searching current sets but can add more sets, add them
            if !hasMoreCardsInCurrentSets && hasMoreSetsToAdd {
                print("🔄 Adding next 2 sets to search...")
                searchProgress.loadNextTwoSets()
                consecutiveEmptyBatches = 0  // Reset empty batch counter for new sets
            }
            
            canLoadMore = searchProgress.currentSetIndex < searchProgress.setsToSearch.count
        }
        
        print("✅ Batch complete: \(newCards.count) new results, \(searchResults.count) total results, can load more: \(canLoadMore)")
    }
    
    private func loadCardsFromSet(setId: String) async throws -> [OnePieceCard] {
        let urlString = "\(baseURL)/sets/\(setId)/"
        print("🌐 API Call: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response")
            throw APIError.serverError
        }
        
        print("📡 HTTP Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            print("❌ HTTP Error: \(httpResponse.statusCode)")
            print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw APIError.serverError
        }
        
        do {
            let cards = try JSONDecoder().decode([OnePieceCard].self, from: data)
            print("✅ Successfully decoded \(cards.count) cards")
            return cards
        } catch {
            print("❌ JSON Decode Error: \(error)")
            print("📄 Raw data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw APIError.decodingError
        }
    }
    
    func getCardById(cardId: String, searchId: UUID) async -> OnePieceCard? {
        do {
            // Check if search is still current before making request
            guard currentSearchId == searchId else {
                return nil
            }
            
            let urlString = "\(baseURL)/sets/card/\(cardId)/"
            
            guard let url = URL(string: urlString) else {
                print("❌ Invalid URL: \(urlString)")
                return nil
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Check again if search is still current after network request
            guard currentSearchId == searchId else {
                return nil
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response for \(cardId)")
                return nil
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let cards = try JSONDecoder().decode([OnePieceCard].self, from: data)
                    if let card = cards.first {
                        return card
                    } else {
                        return nil
                    }
                } catch {
                    print("❌ JSON Decode Error for \(cardId): \(error)")
                    return nil
                }
            } else if httpResponse.statusCode == 404 {
                // Card doesn't exist, this is normal when scanning - don't log
                return nil
            } else if httpResponse.statusCode == 429 {
                // Rate limited - expected during heavy searching - don't log as error
                return nil
            } else {
                print("❌ HTTP Error \(httpResponse.statusCode) for \(cardId)")
                return nil
            }
            
        } catch {
            // Check if this is a cancellation error (expected)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                // Request was cancelled - this is expected, don't log as error
                return nil
            } else {
                // Only log real network errors
                print("❌ Network error for \(cardId): \(error)")
                return nil
            }
        }
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
