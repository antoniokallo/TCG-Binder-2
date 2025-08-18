import Foundation
import SwiftUI

enum BinderType: String, CaseIterable, Codable, Identifiable {
    case green = "green"
    case purple = "purple" 
    case black = "black"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .green: return "Classic Green"
        case .purple: return "Royal Purple"
        case .black: return "Shadow Black"
        }
    }
    
    var imageName: String {
        switch self {
        case .green: return "binder2"
        case .purple: return "binder2-purple"
        case .black: return "binder2-black"
        }
    }
    
    var color: Color {
        switch self {
        case .green: return Color("BinderGreen")
        case .purple: return Color(red: 0.6, green: 0.4, blue: 0.8) // Solid matte purple
        case .black: return Color(red: 0.2, green: 0.2, blue: 0.2) // Solid matte dark gray
        }
    }
    
    var defaultName: String {
        switch self {
        case .green: return "My Green Binder"
        case .purple: return "My Purple Binder"
        case .black: return "My Black Binder"
        }
    }
}

enum TCGType: String, CaseIterable, Codable {
    case onePiece = "one_piece"
    case pokemon = "pokemon"
    
    var displayName: String {
        switch self {
        case .onePiece: return "One Piece"
        case .pokemon: return "Pokémon"
        }
    }
    
    var logoImageName: String {
        switch self {
        case .onePiece: return "logo_op"
        case .pokemon: return "pokemon"
        }
    }
    
    var defaultSets: [TCGSet] {
        switch self {
        case .onePiece:
            return [
                TCGSet(id: "OP-01", name: "Romance Dawn", cards: []),
                TCGSet(id: "OP-02", name: "Paramount War", cards: []),
                TCGSet(id: "OP-03", name: "Pillars of Strength", cards: [])
            ]
        case .pokemon:
            return [
                TCGSet(id: "PKM-Base", name: "Base Set", cards: []),
                TCGSet(id: "PKM-Jungle", name: "Jungle", cards: []),
                TCGSet(id: "PKM-Fossil", name: "Fossil", cards: [])
            ]
        }
    }
}

struct TCGCard: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let imageURL: URL
    let setID: String
    let rarity: String?
    
    // Enhanced API data
    let cardCost: String?
    let cardPower: String?
    let counterAmount: Int?
    let cardColor: String?
    let cardType: String?
    let cardText: String?
    let attribute: String?
    let inventoryPrice: Double?
    let marketPrice: Double?
    let subTypes: String?
    let life: String?
    let trigger: String?
    
    // Custom decoder to handle old saved data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageURL = try container.decode(URL.self, forKey: .imageURL)
        setID = try container.decode(String.self, forKey: .setID)
        rarity = try container.decodeIfPresent(String.self, forKey: .rarity)
        
        // Optional fields with defaults for backward compatibility
        cardCost = try container.decodeIfPresent(String.self, forKey: .cardCost)
        cardPower = try container.decodeIfPresent(String.self, forKey: .cardPower)
        counterAmount = try container.decodeIfPresent(Int.self, forKey: .counterAmount)
        cardColor = try container.decodeIfPresent(String.self, forKey: .cardColor)
        cardType = try container.decodeIfPresent(String.self, forKey: .cardType)
        cardText = try container.decodeIfPresent(String.self, forKey: .cardText)
        attribute = try container.decodeIfPresent(String.self, forKey: .attribute)
        inventoryPrice = try container.decodeIfPresent(Double.self, forKey: .inventoryPrice)
        marketPrice = try container.decodeIfPresent(Double.self, forKey: .marketPrice)
        subTypes = try container.decodeIfPresent(String.self, forKey: .subTypes)
        life = try container.decodeIfPresent(String.self, forKey: .life)
        trigger = try container.decodeIfPresent(String.self, forKey: .trigger)
    }
    
    // Standard init for new cards
    init(id: String, name: String, imageURL: URL, setID: String, rarity: String?,
         cardCost: String? = nil, cardPower: String? = nil, counterAmount: Int? = nil,
         cardColor: String? = nil, cardType: String? = nil, cardText: String? = nil,
         attribute: String? = nil, inventoryPrice: Double? = nil, marketPrice: Double? = nil,
         subTypes: String? = nil, life: String? = nil, trigger: String? = nil) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.setID = setID
        self.rarity = rarity
        self.cardCost = cardCost
        self.cardPower = cardPower
        self.counterAmount = counterAmount
        self.cardColor = cardColor
        self.cardType = cardType
        self.cardText = cardText
        self.attribute = attribute
        self.inventoryPrice = inventoryPrice
        self.marketPrice = marketPrice
        self.subTypes = subTypes
        self.life = life
        self.trigger = trigger
    }
    
    // Convenience computed properties
    var cost: String? { cardCost }
    var power: String? { cardPower }
    var counter: String? { counterAmount != nil ? "\(counterAmount!)" : nil }
    var color: String? { cardColor }
    var type: String? { cardType }
    var effect: String? { cardText }
}

struct TCGSet: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    var cards: [TCGCard]
}