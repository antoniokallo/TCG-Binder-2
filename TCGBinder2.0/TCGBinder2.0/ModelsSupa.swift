//
//  ModelsSupa.swift
//  TCGBinder2.0
//
//  Created by Edward Kogos on 8/15/25.
//

struct Profile: Decodable {
  let username: String?
  let fullName: String?
  let website: String?

  enum CodingKeys: String, CodingKey {
    case username
    case fullName = "full_name"
    case website
  }
}

struct UpdateProfileParams: Encodable {
  let username: String
  let fullName: String
  let website: String

  enum CodingKeys: String, CodingKey {
    case username
    case fullName = "full_name"
    case website
  }
}

// MARK: - Pokemon Card Storage Models
struct UserPokemonCard: Codable, Identifiable {
  let id: Int?
  let userId: String
  let cardId: String
  let qty: Int
  
  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case cardId = "card_id"
    case qty
  }
}

struct CreateUserPokemonCardParams: Encodable {
  let userId: String
  let cardId: String
  let qty: Int
  
  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case cardId = "card_id"
    case qty
  }
}

struct UpdateUserPokemonCardQtyParams: Encodable {
  let qty: Int
  
  enum CodingKeys: String, CodingKey {
    case qty
  }
}
