//
//  OnePieceCardPersistenceService.swift
//  TCGBinder2.0
//
//  One Piece card persistence service for saving/loading user cards to/from Supabase
//

import Foundation
import Supabase

@MainActor
class OnePieceCardPersistenceService: ObservableObject {
    
    // MARK: - Add One Piece Card (increment quantity)
    
    func addOnePieceCard(cardId: String) async throws {
        
        print("➕ Adding One Piece card to Supabase...")
        print("   - Card ID: \(cardId)")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Check if card already exists for this user
        let existingCards: [UserOnePieceCard] = try await supabase
            .from("user_op_cards")
            .select("*")
            .eq("user_id", value: currentUser.id.uuidString)
            .eq("card_id", value: cardId)
            .execute()
            .value
        
        if let existingCard = existingCards.first {
            // Card exists, increment quantity
            let newQty = existingCard.qty + 1
            print("📈 Card exists, incrementing qty from \(existingCard.qty) to \(newQty)")
            
            try await supabase
                .from("user_op_cards")
                .update(UpdateUserOnePieceCardQtyParams(qty: newQty))
                .eq("user_id", value: currentUser.id.uuidString)
                .eq("card_id", value: cardId)
                .execute()
            
            print("✅ One Piece card quantity incremented successfully")
        } else {
            // Card doesn't exist, create new with qty = 1
            print("🆕 Card doesn't exist, creating new with qty = 1")
            
            let cardData = CreateUserOnePieceCardParams(
                userId: currentUser.id.uuidString,
                cardId: cardId,
                qty: 1
            )
            
            try await supabase
                .from("user_op_cards")
                .insert(cardData)
                .execute()
            
            print("✅ One Piece card created successfully")
        }
    }
    
    // MARK: - Load One Piece Cards from USER_OP_CARDS table
    
    func loadOnePieceCards() async throws -> [UserOnePieceCard] {
        print("📥 Loading One Piece cards from Supabase...")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        let userCards: [UserOnePieceCard] = try await supabase
            .from("user_op_cards")
            .select("*")
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        print("✅ Loaded \(userCards.count) One Piece cards from Supabase")
        return userCards
    }
    
    // MARK: - Remove One Piece Card (decrement quantity)
    
    func removeOnePieceCard(cardId: String) async throws {
        print("➖ Removing One Piece card from Supabase...")
        print("   - Card ID: \(cardId)")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Check if card exists for this user
        let existingCards: [UserOnePieceCard] = try await supabase
            .from("user_op_cards")
            .select("*")
            .eq("user_id", value: currentUser.id.uuidString)
            .eq("card_id", value: cardId)
            .execute()
            .value
        
        guard let existingCard = existingCards.first else {
            print("⚠️ Card not found in user's collection, nothing to remove")
            return
        }
        
        if existingCard.qty > 1 {
            // Card has multiple copies, decrement quantity
            let newQty = existingCard.qty - 1
            print("📉 Card has \(existingCard.qty) copies, decrementing to \(newQty)")
            
            try await supabase
                .from("user_op_cards")
                .update(UpdateUserOnePieceCardQtyParams(qty: newQty))
                .eq("user_id", value: currentUser.id.uuidString)
                .eq("card_id", value: cardId)
                .execute()
            
            print("✅ One Piece card quantity decremented successfully")
        } else {
            // Card has only 1 copy, delete the record entirely
            print("🗑️ Card has only 1 copy, deleting record entirely")
            
            try await supabase
                .from("user_op_cards")
                .delete()
                .eq("user_id", value: currentUser.id.uuidString)
                .eq("card_id", value: cardId)
                .execute()
            
            print("✅ One Piece card record deleted successfully")
        }
    }
    
    // MARK: - Get One Piece Card Details
    
    func getOnePieceCardDetails(for cardIds: [String]) async throws -> [OnePieceCard] {
        guard !cardIds.isEmpty else { return [] }
        
        print("📋 Fetching One Piece card details for \(cardIds.count) cards")
        
        let onepieceCards: [OnePieceCard] = try await supabase
            .from("op_cards")
            .select("*")
            .in("id", values: cardIds)
            .execute()
            .value
        
        print("✅ Retrieved \(onepieceCards.count) One Piece card details")
        return onepieceCards
    }
    
    // MARK: - Clear All One Piece Cards for User
    
    func clearAllOnePieceCards() async throws {
        print("🧹 Clearing all One Piece cards for user...")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        try await supabase
            .from("user_op_cards")
            .delete()
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
        
        print("✅ All One Piece cards cleared from Supabase")
    }
    
    // MARK: - Cleanup invalid quantities
    
    func cleanupInvalidQuantities() async throws {
        print("🧹 Cleaning up One Piece cards with invalid quantities...")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Delete any cards with qty <= 0
        try await supabase
            .from("user_op_cards")
            .delete()
            .eq("user_id", value: currentUser.id.uuidString)
            .lte("qty", value: 0)
            .execute()
        
        print("✅ Invalid quantity records cleaned up")
    }
}