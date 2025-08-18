import Foundation

struct TCGCard: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let imageURL: URL
    let setID: String
    let rarity: String?
}

struct TCGSet: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    var cards: [TCGCard]
}