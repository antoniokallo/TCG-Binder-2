import Foundation
import SwiftUI

@MainActor
final class BinderViewModel: ObservableObject {
    @Published var sets: [TCGSet] = []
    @Published var currentSetID: String? = nil
    @Published var favorites: Set<String> = []
    @Published var query: String = ""
    @Published var searchResults: [TCGCard] = []
    @Published var spreadIndexBySet: [String: Int] = [:]

    private let favoritesKey = "binder.favorites"
    private let spreadsKey   = "binder.spreadIndexBySet"

    init() {
        loadPersisted()
        loadMockSets()
        if currentSetID == nil { currentSetID = sets.first?.id }
    }

    // MARK: - Paging / spreads

    func spreads(for set: TCGSet) -> [[TCGCard]] {
        let pageSize = 9
        let spreadSize = pageSize * 2
        var result: [[TCGCard]] = []
        var index = 0
        while index < set.cards.count {
            let end = min(index + spreadSize, set.cards.count)
            result.append(Array(set.cards[index..<end]))
            index += spreadSize
        }
        return result
    }

    func currentSpreadIndex(for setID: String) -> Int {
        spreadIndexBySet[setID] ?? 0
    }

    func setSpreadIndex(_ i: Int, for setID: String) {
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
        let spread = idx / 18
        setSpreadIndex(spread, for: set.id)
        query = ""
        searchResults = []
    }

    // MARK: - Favorites

    func toggleFavorite(_ card: TCGCard) {
        if favorites.contains(card.id) {
            favorites.remove(card.id)
        } else {
            favorites.insert(card.id)
        }
        persist()
    }

    // MARK: - Persistence

    private func loadPersisted() {
        let ud = UserDefaults.standard
        if let data = ud.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.favorites = decoded
        }
        if let data = ud.data(forKey: spreadsKey),
           let decoded = try? JSONDecoder().decode([String:Int].self, from: data) {
            self.spreadIndexBySet = decoded
        }
    }

    private func persist() {
        let ud = UserDefaults.standard
        if let data = try? JSONEncoder().encode(favorites) {
            ud.set(data, forKey: favoritesKey)
        }
        if let data = try? JSONEncoder().encode(spreadIndexBySet) {
            ud.set(data, forKey: spreadsKey)
        }
    }

    // MARK: - Mock data

    private func loadMockSets() {
        // Create empty sets - users will add cards themselves
        let setA = TCGSet(id: "OP-01", name: "Romance Dawn", cards: [])
        let setB = TCGSet(id: "OP-02", name: "Paramount War", cards: [])
        let setC = TCGSet(id: "Pkm-Base", name: "Pokémon Base", cards: [])

        self.sets = [setA, setB, setC]
    }
}