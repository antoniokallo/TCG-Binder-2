//
//  ModelsSupa.swift
//  TCGBinder2.0
//
//  Created by Edward Kogos on 8/15/25.
//

import Foundation

struct Profile: Decodable {
  let username: String?
  let fullName: String?
  let website: String?
  let bio: String?
  let avatarUrl: String?

  enum CodingKeys: String, CodingKey {
    case username
    case fullName = "full_name"
    case website
    case bio
    case avatarUrl = "avatar_url"
  }
}

struct UpdateProfileParams: Encodable {
  let username: String
  let fullName: String
  let website: String
  let bio: String
  let avatarUrl: String?

  enum CodingKeys: String, CodingKey {
    case username
    case fullName = "full_name"
    case website
    case bio
    case avatarUrl = "avatar_url"
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

// MARK: - YuGiOh Card Storage Models
struct UserYuGiOhCard: Codable, Identifiable {
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

struct CreateUserYuGiOhCardParams: Encodable {
  let userId: String
  let cardId: String
  let qty: Int
  
  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case cardId = "card_id"
    case qty
  }
}

struct UpdateUserYuGiOhCardQtyParams: Encodable {
  let qty: Int
  
  enum CodingKeys: String, CodingKey {
    case qty
  }
}

// MARK: - One Piece Card Storage Models
struct UserOnePieceCard: Codable, Identifiable {
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

struct CreateUserOnePieceCardParams: Encodable {
  let userId: String
  let cardId: String
  let qty: Int
  
  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case cardId = "card_id"
    case qty
  }
}

struct UpdateUserOnePieceCardQtyParams: Encodable {
  let qty: Int
  
  enum CodingKeys: String, CodingKey {
    case qty
  }
}

// MARK: - Binder-Specific Card Storage Models

struct UserBinderCard: Codable, Identifiable {
  let id: String? // This will be the database UUID primary key
  let binderId: String
  let cardId: String // This needs to be the card identifier, not UUID
  let qty: Int
  let notes: String?
  let condition: String?
  let addedAt: String?
  
  enum CodingKeys: String, CodingKey {
    case id
    case binderId = "binder_id"
    case cardId = "card_id"
    case qty
    case notes
    case condition
    case addedAt = "added_at"
  }
}

struct CreateUserBinderCardParams: Encodable {
  let binderId: String
  let cardId: String
  let qty: Int
  let notes: String?
  let condition: String?
  
  enum CodingKeys: String, CodingKey {
    case binderId = "binder_id"
    case cardId = "card_id"
    case qty
    case notes
    case condition
  }
}

struct UpdateUserBinderCardQtyParams: Encodable {
  let qty: Int
  
  enum CodingKeys: String, CodingKey {
    case qty
  }
}

// MARK: - Friend Request Models

struct FriendRequest: Codable, Identifiable {
    let id: String?
    let requesterId: String
    let addresseeId: String
    let status: String
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case createdAt = "created_at"
    }
}

struct CreateFriendRequestParams: Encodable {
    let requesterId: String
    let addresseeId: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
    }
}

struct UpdateFriendRequestParams: Encodable {
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case status
    }
}

// MARK: - Friend and User Search Models

struct UserSearchResult: Codable, Identifiable {
    let id: String
    let username: String?
    let fullName: String?
    let bio: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case bio
        case avatarUrl = "avatar_url"
    }
}

// Friend request status types
enum FriendRequestStatus: String, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Friends"
        case .declined: return "Declined"
        }
    }
}
