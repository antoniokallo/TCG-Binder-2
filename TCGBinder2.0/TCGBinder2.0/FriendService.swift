//
//  FriendService.swift
//  TCGBinder2.0
//
//  Service for managing friend requests, user search, and friend relationships
//

import Foundation
import SwiftUI
import Supabase

@MainActor
class FriendService: ObservableObject {
    
    // MARK: - User Search
    
    func searchUsersByUsername(_ query: String) async throws -> [UserSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let users: [UserSearchResult] = try await supabase
            .from("profiles")
            .select("id, username, full_name, bio, avatar_url")
            .ilike("username", pattern: "%\(searchQuery)%")
            .limit(20)
            .execute()
            .value
        
        return users
    }
    
    func getUserById(_ userId: String) async throws -> UserSearchResult {
        let user: UserSearchResult = try await supabase
            .from("profiles")
            .select("id, username, full_name, bio, avatar_url")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        return user
    }
    
    // MARK: - Friend Requests
    
    func sendFriendRequest(from requesterId: String, to addresseeId: String) async throws {
        // Check if friend request already exists
        let existingRequests: [FriendRequest] = try await supabase
            .from("friend_requests")
            .select()
            .eq("requester_id", value: requesterId)
            .eq("addressee_id", value: addresseeId)
            .execute()
            .value
        
        guard existingRequests.isEmpty else {
            throw FriendServiceError.requestAlreadyExists
        }
        
        // Check if reverse request exists (addressee already sent request to requester)
        let reverseRequests: [FriendRequest] = try await supabase
            .from("friend_requests")
            .select()
            .eq("requester_id", value: addresseeId)
            .eq("addressee_id", value: requesterId)
            .execute()
            .value
        
        if let reverseRequest = reverseRequests.first, reverseRequest.status == "pending" {
            // Automatically accept the reverse request
            try await updateFriendRequest(requestId: reverseRequest.id!, status: .accepted)
            return
        }
        
        // Create new friend request
        let params = CreateFriendRequestParams(
            requesterId: requesterId,
            addresseeId: addresseeId,
            status: FriendRequestStatus.pending.rawValue
        )
        
        try await supabase
            .from("friend_requests")
            .insert(params)
            .execute()
    }
    
    func updateFriendRequest(requestId: String, status: FriendRequestStatus) async throws {
        let params = UpdateFriendRequestParams(status: status.rawValue)
        
        try await supabase
            .from("friend_requests")
            .update(params)
            .eq("id", value: requestId)
            .execute()
    }
    
    func getFriendRequestsReceived(for userId: String) async throws -> [FriendRequest] {
        let requests: [FriendRequest] = try await supabase
            .from("friend_requests")
            .select()
            .eq("addressee_id", value: userId)
            .eq("status", value: FriendRequestStatus.pending.rawValue)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return requests
    }
    
    func getFriendRequestsSent(from userId: String) async throws -> [FriendRequest] {
        let requests: [FriendRequest] = try await supabase
            .from("friend_requests")
            .select()
            .eq("requester_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return requests
    }
    
    // MARK: - Friends Management
    
    func getFriends(for userId: String) async throws -> [UserSearchResult] {
        // Get accepted friend requests where user is either requester or addressee
        let sentRequests: [FriendRequest] = try await supabase
            .from("friend_requests")
            .select()
            .eq("requester_id", value: userId)
            .eq("status", value: FriendRequestStatus.accepted.rawValue)
            .execute()
            .value
        
        let receivedRequests: [FriendRequest] = try await supabase
            .from("friend_requests")
            .select()
            .eq("addressee_id", value: userId)
            .eq("status", value: FriendRequestStatus.accepted.rawValue)
            .execute()
            .value
        
        // Collect friend user IDs
        var friendIds: Set<String> = []
        
        for request in sentRequests {
            friendIds.insert(request.addresseeId)
        }
        
        for request in receivedRequests {
            friendIds.insert(request.requesterId)
        }
        
        // Fetch friend profiles
        var friends: [UserSearchResult] = []
        for friendId in friendIds {
            do {
                let friend = try await getUserById(friendId)
                friends.append(friend)
            } catch {
                debugPrint("Failed to load friend profile for ID: \(friendId)")
            }
        }
        
        return friends.sorted { ($0.username ?? "") < ($1.username ?? "") }
    }
    
    func areFriends(userId1: String, userId2: String) async throws -> Bool {
        // Check if there's an accepted friend request between these users
        let requests: [FriendRequest] = try await supabase
            .from("friend_requests")
            .select()
            .or("and(requester_id.eq.\(userId1),addressee_id.eq.\(userId2)),and(requester_id.eq.\(userId2),addressee_id.eq.\(userId1))")
            .eq("status", value: FriendRequestStatus.accepted.rawValue)
            .execute()
            .value
        
        return !requests.isEmpty
    }
    
    func getFriendRequestStatus(from requesterId: String, to addresseeId: String) async throws -> FriendRequestStatus? {
        let requests: [FriendRequest] = try await supabase
            .from("friend_requests")
            .select()
            .eq("requester_id", value: requesterId)
            .eq("addressee_id", value: addresseeId)
            .execute()
            .value
        
        if let request = requests.first {
            return FriendRequestStatus(rawValue: request.status)
        }
        return nil
    }
    
    // MARK: - Friend Binder Access
    
    func getFriendBinders(friendId: String) async throws -> [UserBinder] {
        let binders: [UserBinder] = try await supabase
            .from("user_binders")
            .select()
            .eq("user_id", value: friendId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return binders
    }
    
    func getFriendBinderCards(binderId: String) async throws -> [UserBinderCard] {
        print("📡 [DEBUG] Querying database for binder cards")
        print("📡 [DEBUG] Binder ID: '\(binderId)'")
        
        let cards: [UserBinderCard] = try await supabase
            .from("user_binder_cards")
            .select()
            .eq("binder_id", value: binderId)
            .order("added_at", ascending: false)
            .execute()
            .value
        
        print("📡 [DEBUG] Database query returned \(cards.count) cards")
        for (index, card) in cards.enumerated() {
            print("📡 [DEBUG] DB Card \(index): binderId='\(card.binderId)', cardId='\(card.cardId)', qty=\(card.qty)")
        }
        
        return cards
    }
    
    // Batch load card details for multiple cards (same approach as BinderCardService)
    func getCardDetails(for binderCards: [UserBinderCard], cardType: TCGType) async throws -> [TCGCard] {
        guard !binderCards.isEmpty else { return [] }
        
        let cardIds = binderCards.map { $0.cardId }
        print("📋 [DEBUG] Fetching card details for \(cardIds.count) \(cardType.rawValue) cards")
        print("🔍 [DEBUG] Card IDs to lookup: \(cardIds.prefix(5))") // Show first 5 IDs for debugging
        
        switch cardType {
        case .pokemon:
            struct PokemonCard: Codable {
                let id: String
                let name: String?
                let setCode: String?
                let rarity: String?
                let imageUrl: String?
                
                enum CodingKeys: String, CodingKey {
                    case id, name, rarity
                    case setCode = "set_code"
                    case imageUrl = "image_url"
                }
            }
            
            let pokemonCards: [PokemonCard] = try await supabase
                .from("pkm_cards")
                .select("id, name, set_code, rarity, image_url")
                .in("id", values: cardIds)
                .execute()
                .value
            
            print("✅ [DEBUG] Retrieved \(pokemonCards.count) Pokemon card details")
            return pokemonCards.map { card in
                TCGCard(
                    id: card.id,
                    name: card.name ?? "Unknown Card",
                    imageURL: URL(string: card.imageUrl ?? "") ?? URL(string: "about:blank")!,
                    setID: card.setCode ?? "unknown",
                    rarity: card.rarity
                )
            }
            
        case .yugioh:
            struct YugiohCard: Codable {
                let id: String
                let name: String?
                let type: String?
                let frameType: String?
                let description: String?
                let imageUrl: String?
                
                enum CodingKeys: String, CodingKey {
                    case id, name, type, description
                    case frameType = "frame_type"
                    case imageUrl = "image_url"
                }
            }
            
            let yugiohCards: [YugiohCard] = try await supabase
                .from("ygo_cards")
                .select("id, name, type, frame_type, description, image_url")
                .in("id", values: cardIds)
                .execute()
                .value
            
            print("✅ [DEBUG] Retrieved \(yugiohCards.count) Yu-Gi-Oh! card details")
            return yugiohCards.map { card in
                TCGCard(
                    id: card.id,
                    name: card.name ?? "Unknown Card",
                    imageURL: URL(string: card.imageUrl ?? "") ?? URL(string: "about:blank")!,
                    setID: card.frameType ?? "unknown",
                    rarity: nil,
                    cardType: card.type,
                    cardText: card.description
                )
            }
            
        case .onePiece:
            struct OnePieceCard: Codable {
                let id: String
                let name: String?
                let cost: Int?
                let power: Int?
                let counter: Int?
                let color: String?
                let type: String?
                let effect: String?
                let trigger: String?
                let setCode: String?
                let rarity: String?
                let imageUrl: String?
                
                enum CodingKeys: String, CodingKey {
                    case id, name, cost, power, counter, color, type, effect, trigger, rarity
                    case setCode = "set_code"
                    case imageUrl = "image_url"
                }
            }
            
            let onePieceCards: [OnePieceCard] = try await supabase
                .from("op_cards")
                .select("id, name, cost, power, counter, color, type, effect, trigger, set_code, rarity, image_url")
                .in("id", values: cardIds)
                .execute()
                .value
            
            print("✅ [DEBUG] Retrieved \(onePieceCards.count) One Piece card details")
            return onePieceCards.map { card in
                TCGCard(
                    id: card.id,
                    name: card.name ?? "Unknown Card",
                    imageURL: URL(string: card.imageUrl ?? "") ?? URL(string: "about:blank")!,
                    setID: card.setCode ?? "unknown",
                    rarity: card.rarity,
                    cardCost: card.cost != nil ? String(card.cost!) : nil,
                    cardPower: card.power != nil ? String(card.power!) : nil,
                    counterAmount: card.counter,
                    cardColor: card.color,
                    cardType: card.type,
                    cardText: card.effect,
                    trigger: card.trigger
                )
            }
        }
    }
    
    // Convert UserBinderCard to TCGCard with full details (keep for backward compatibility)
    func getFullCardDetails(for binderCard: UserBinderCard) async throws -> TCGCard {
        let cardUUID = binderCard.cardId
        print("🔧 [DEBUG] getFullCardDetails called with UUID: '\(cardUUID)'")
        
        // First, get the game type and source_id from all_cards table
        struct AllCardReference: Codable {
            let id: String
            let game: String?
            let sourceId: String?
            let code: String?
            let name: String?
            let setCode: String?
            
            enum CodingKeys: String, CodingKey {
                case id
                case game
                case sourceId = "source_id"
                case code
                case name
                case setCode = "set_code"
            }
        }
        
        print("🔧 [DEBUG] Querying all_cards table for UUID: '\(cardUUID)'")
        
        let allCardRefs: [AllCardReference] = try await supabase
            .from("all_cards")
            .select("id, game, source_id, code, name, set_code")
            .eq("id", value: cardUUID)
            .execute()
            .value
        
        guard let cardRef = allCardRefs.first else {
            print("❌ [DEBUG] No card found in all_cards for UUID: \(cardUUID)")
            return TCGCard(
                id: cardUUID,
                name: "Unknown Card",
                imageURL: URL(string: "about:blank")!,
                setID: "unknown",
                rarity: nil
            )
        }
        
        print("🔧 [DEBUG] Found card reference:")
        print("🔧 [DEBUG] - Game: '\(cardRef.game ?? "nil")'")
        print("🔧 [DEBUG] - Source ID: '\(cardRef.sourceId ?? "nil")'")
        print("🔧 [DEBUG] - Code: '\(cardRef.code ?? "nil")'")
        print("🔧 [DEBUG] - Name: '\(cardRef.name ?? "nil")'")
        print("🔧 [DEBUG] - Set Code: '\(cardRef.setCode ?? "nil")'")
        
        // Now query the game-specific table based on the game type using the same UUID
        guard let game = cardRef.game?.lowercased() else {
            print("❌ [DEBUG] Missing game type")
            return TCGCard(
                id: cardUUID,
                name: cardRef.name ?? "Unknown Card",
                imageURL: URL(string: "about:blank")!,
                setID: cardRef.setCode ?? "unknown",
                rarity: nil
            )
        }
        
        var tcgCard: TCGCard
        
        if game == "one_piece" || game == "op" {
            print("🔧 [DEBUG] Querying op_cards table for ID: '\(cardUUID)'")
            
            struct OnePieceCard: Codable {
                let id: String
                let name: String?
                let cost: String?
                let power: String?
                let counter: String?
                let color: String?
                let type: String?
                let effect: String?
                let trigger: String?
                let setCode: String?
                let rarity: String?
                let imageUrl: String?
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case name
                    case cost
                    case power
                    case counter
                    case color
                    case type
                    case effect
                    case trigger
                    case setCode = "set_code"
                    case rarity
                    case imageUrl = "image_url"
                }
            }
            
            let opCards: [OnePieceCard] = try await supabase
                .from("op_cards")
                .select("id, name, cost, power, counter, color, type, effect, trigger, set_code, rarity, image_url")
                .eq("id", value: cardUUID)
                .execute()
                .value
            
            if let opCard = opCards.first {
                print("🔧 [DEBUG] Found One Piece card: '\(opCard.name ?? "nil")'")
                let imageURL = URL(string: opCard.imageUrl ?? "") ?? URL(string: "about:blank")!
                
                tcgCard = TCGCard(
                    id: opCard.id,
                    name: opCard.name ?? "Unknown Card",
                    imageURL: imageURL,
                    setID: opCard.setCode ?? "unknown",
                    rarity: opCard.rarity,
                    cardCost: opCard.cost,
                    cardPower: opCard.power,
                    counterAmount: Int(opCard.counter ?? "0"),
                    cardColor: opCard.color,
                    cardType: opCard.type,
                    cardText: opCard.effect,
                    trigger: opCard.trigger
                )
            } else {
                print("❌ [DEBUG] No One Piece card found for ID: \(cardUUID)")
                tcgCard = TCGCard(
                    id: cardUUID,
                    name: cardRef.name ?? "Unknown Card",
                    imageURL: URL(string: "about:blank")!,
                    setID: cardRef.setCode ?? "unknown",
                    rarity: nil
                )
            }
            
        } else if game == "pokemon" || game == "pkm" {
            print("🔧 [DEBUG] Querying pkm_cards table for ID: '\(cardUUID)'")
            
            struct PokemonCard: Codable {
                let id: String
                let name: String?
                let setCode: String?
                let rarity: String?
                let imageUrl: String?
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case name
                    case setCode = "set_code"
                    case rarity
                    case imageUrl = "image_url"
                }
            }
            
            let pkmCards: [PokemonCard] = try await supabase
                .from("pkm_cards")
                .select("id, name, set_code, rarity, image_url")
                .eq("id", value: cardUUID)
                .execute()
                .value
            
            if let pkmCard = pkmCards.first {
                print("🔧 [DEBUG] Found Pokemon card: '\(pkmCard.name ?? "nil")'")
                let imageURL = URL(string: pkmCard.imageUrl ?? "") ?? URL(string: "about:blank")!
                
                tcgCard = TCGCard(
                    id: pkmCard.id,
                    name: pkmCard.name ?? "Unknown Card",
                    imageURL: imageURL,
                    setID: pkmCard.setCode ?? "unknown",
                    rarity: pkmCard.rarity
                )
            } else {
                print("❌ [DEBUG] No Pokemon card found for ID: \(cardUUID)")
                tcgCard = TCGCard(
                    id: cardUUID,
                    name: cardRef.name ?? "Unknown Card",
                    imageURL: URL(string: "about:blank")!,
                    setID: cardRef.setCode ?? "unknown",
                    rarity: nil
                )
            }
            
        } else if game == "yugioh" || game == "ygo" {
            print("🔧 [DEBUG] Querying ygo_cards table for ID: '\(cardUUID)'")
            
            struct YugiohCard: Codable {
                let id: String
                let name: String?
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
            
            let ygoCards: [YugiohCard] = try await supabase
                .from("ygo_cards")
                .select("id, name, type, frame_type, description, image_url")
                .eq("id", value: cardUUID)
                .execute()
                .value
            
            if let ygoCard = ygoCards.first {
                print("🔧 [DEBUG] Found Yu-Gi-Oh card: '\(ygoCard.name ?? "nil")'")
                let imageURL = URL(string: ygoCard.imageUrl ?? "") ?? URL(string: "about:blank")!
                
                tcgCard = TCGCard(
                    id: ygoCard.id,
                    name: ygoCard.name ?? "Unknown Card",
                    imageURL: imageURL,
                    setID: ygoCard.frameType ?? "unknown",
                    rarity: nil,
                    cardType: ygoCard.type,
                    cardText: ygoCard.description
                )
            } else {
                print("❌ [DEBUG] No Yu-Gi-Oh card found for ID: \(cardUUID)")
                tcgCard = TCGCard(
                    id: cardUUID,
                    name: cardRef.name ?? "Unknown Card",
                    imageURL: URL(string: "about:blank")!,
                    setID: cardRef.setCode ?? "unknown",
                    rarity: nil
                )
            }
            
        } else {
            print("❌ [DEBUG] Unknown game type: \(game)")
            tcgCard = TCGCard(
                id: cardUUID,
                name: cardRef.name ?? "Unknown Card",
                imageURL: URL(string: "about:blank")!,
                setID: cardRef.setCode ?? "unknown",
                rarity: nil
            )
        }
        
        print("🔧 [DEBUG] Created TCGCard:")
        print("🔧 [DEBUG] - ID: '\(tcgCard.id)'")
        print("🔧 [DEBUG] - Name: '\(tcgCard.name)'")
        print("🔧 [DEBUG] - ImageURL: '\(tcgCard.imageURL.absoluteString)'")
        print("🔧 [DEBUG] - SetID: '\(tcgCard.setID)'")
        print("🔧 [DEBUG] - Rarity: '\(tcgCard.rarity ?? "nil")'")
        
        return tcgCard
    }
}

// MARK: - Friend Service Errors

enum FriendServiceError: LocalizedError {
    case requestAlreadyExists
    case userNotFound
    case invalidRequest
    
    var errorDescription: String? {
        switch self {
        case .requestAlreadyExists:
            return "Friend request already exists"
        case .userNotFound:
            return "User not found"
        case .invalidRequest:
            return "Invalid friend request"
        }
    }
}