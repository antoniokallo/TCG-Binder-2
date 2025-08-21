import Foundation
import SwiftUI

// MARK: - App Color Scheme

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - User Binder Models

// Model for user_binders table in Supabase
struct UserBinder: Codable, Equatable {
    let id: String?
    let user_id: String
    let binder_type: String
    let name: String
    let assigned_value: Double
    let binder_color: String?
    let game: String?
    let created_at: String?
    let updated_at: String?
    
    // Computed property to get SwiftUI Color from database color string
    var color: Color {
        guard let colorString = binder_color else {
            return Color.black // Default fallback
        }
        
        switch colorString.lowercased() {
        case "black": return Color.black
        case "blue": return Color.blue
        case "red": return Color.red
        case "green": return Color.green
        case "purple": return Color.purple
        case "orange": return Color.orange
        case "yellow": return Color.yellow
        case "pink": return Color.pink
        case "brown": return Color.brown
        case "gray", "grey": return Color.gray
        default: return Color.black
        }
    }
    
    // Static method to convert SwiftUI Color to database string
    static func colorToString(_ color: Color) -> String {
        // Since SwiftUI Color doesn't support direct equality comparison,
        // we'll use a more robust approach by converting to description or using RGB values
        // For now, let's use a practical approach with common colors
        
        // Check against common system colors by description
        let colorDescription = String(describing: color)
        
        if colorDescription.contains("black") || color == Color(.black) {
            return "black"
        } else if colorDescription.contains("blue") || color == Color(.systemBlue) {
            return "blue"
        } else if colorDescription.contains("red") || color == Color(.systemRed) {
            return "red"
        } else if colorDescription.contains("green") || color == Color(.systemGreen) {
            return "green"
        } else if colorDescription.contains("purple") || color == Color(.systemPurple) {
            return "purple"
        } else if colorDescription.contains("orange") || color == Color(.systemOrange) {
            return "orange"
        } else if colorDescription.contains("yellow") || color == Color(.systemYellow) {
            return "yellow"
        } else if colorDescription.contains("pink") || color == Color(.systemPink) {
            return "pink"
        } else if colorDescription.contains("brown") || color == Color(.brown) {
            return "brown"
        } else if colorDescription.contains("gray") || colorDescription.contains("grey") || color == Color(.systemGray) {
            return "gray"
        } else {
            return "black" // Default fallback
        }
    }
}

struct CreateUserBinderParams: Codable {
    let userId: String
    let binderType: String
    let name: String
    let assignedValue: Int
    let binderColor: String?
    let game: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case binderType = "binder_type"
        case name = "name"
        case assignedValue = "assigned_value"
        case binderColor = "binder_color"
        case game = "game"
    }
}

struct UpdateUserBinderValueParams: Codable {
    let assignedValue: Double
    
    enum CodingKeys: String, CodingKey {
        case assignedValue = "assigned_value"
    }
}

enum BinderType: String, CaseIterable, Codable, Identifiable {
    case black = "black"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        return "Shadow Black"
    }
    
    var imageName: String {
        return "binder2-black"
    }
    
    var color: Color {
        return Color(red: 0.2, green: 0.2, blue: 0.2) // Solid matte dark gray
    }
    
    var defaultName: String {
        return "My Black Binder"
    }
}

enum TCGType: String, CaseIterable, Codable {
    case onePiece = "one_piece"
    case pokemon = "pokemon"
    case yugioh = "yugioh"
    
    var displayName: String {
        switch self {
        case .onePiece: return "One Piece"
        case .pokemon: return "Pokémon"
        case .yugioh: return "Yu-Gi-Oh!"
        }
    }
    
    var logoImageName: String {
        switch self {
        case .onePiece: return "logo_op"
        case .pokemon: return "pokemon"
        case .yugioh: return "yugioh"
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
        case .yugioh:
            return [
                TCGSet(id: "YGO-LOB", name: "Legend of Blue Eyes", cards: []),
                TCGSet(id: "YGO-MRD", name: "Metal Raiders", cards: []),
                TCGSet(id: "YGO-SRL", name: "Spell Ruler", cards: [])
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

// MARK: - YuGiOh Card Models

struct YuGiOhCard: Codable {
    let id: String?
    let name: String
    let type: String?
    let frameType: String?
    let description: String?
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case frameType = "frame_type"
        case description
        case imageUrl = "image_url"
    }
}