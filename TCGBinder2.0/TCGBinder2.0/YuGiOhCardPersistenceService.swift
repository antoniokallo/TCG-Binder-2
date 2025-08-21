//
//  YuGiOhCardPersistenceService.swift
//  TCGBinder2.0
//
//  Yu-Gi-Oh! card persistence service for saving/loading user cards to/from Supabase
//

import Foundation
import Supabase

@MainActor
class YuGiOhCardPersistenceService: ObservableObject {
    
    // MARK: - Add Yu-Gi-Oh! Card (increment quantity)
    
    func addYuGiOhCard(cardId: String) async throws {
        
        print("➕ Adding Yu-Gi-Oh! card to Supabase...")
        print("   - Card ID: \(cardId)")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Check if card already exists for this user
        let existingCards: [UserYuGiOhCard] = try await supabase
            .from("user_ygo_cards")
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
                .from("user_ygo_cards")
                .update(UpdateUserYuGiOhCardQtyParams(qty: newQty))
                .eq("user_id", value: currentUser.id.uuidString)
                .eq("card_id", value: cardId)
                .execute()
            
            print("✅ Yu-Gi-Oh! card quantity incremented successfully")
        } else {
            // Card doesn't exist, create new with qty = 1
            print("🆕 Card doesn't exist, creating new with qty = 1")
            
            let cardData = CreateUserYuGiOhCardParams(
                userId: currentUser.id.uuidString,
                cardId: cardId,
                qty: 1
            )
            
            try await supabase
                .from("user_ygo_cards")
                .insert(cardData)
                .execute()
            
            print("✅ Yu-Gi-Oh! card created successfully")
        }
    }
    
    // MARK: - Load Yu-Gi-Oh! Cards from USER_YGO_CARDS table
    
    func loadYuGiOhCards() async throws -> [UserYuGiOhCard] {
        print("📥 Loading Yu-Gi-Oh! cards from Supabase...")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        let userCards: [UserYuGiOhCard] = try await supabase
            .from("user_ygo_cards")
            .select("*")
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        print("✅ Loaded \(userCards.count) Yu-Gi-Oh! cards from Supabase")
        return userCards
    }
    
    // MARK: - Remove Yu-Gi-Oh! Card (decrement quantity)
    
    func removeYuGiOhCard(cardId: String) async throws {
        print("➖ Removing Yu-Gi-Oh! card from Supabase...")
        print("   - Card ID: \(cardId)")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Check if card exists for this user
        let existingCards: [UserYuGiOhCard] = try await supabase
            .from("user_ygo_cards")
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
                .from("user_ygo_cards")
                .update(UpdateUserYuGiOhCardQtyParams(qty: newQty))
                .eq("user_id", value: currentUser.id.uuidString)
                .eq("card_id", value: cardId)
                .execute()
            
            print("✅ Yu-Gi-Oh! card quantity decremented successfully")
        } else {
            // Card has only 1 copy, delete the record entirely
            print("🗑️ Card has only 1 copy, deleting record entirely")
            
            try await supabase
                .from("user_ygo_cards")
                .delete()
                .eq("user_id", value: currentUser.id.uuidString)
                .eq("card_id", value: cardId)
                .execute()
            
            print("✅ Yu-Gi-Oh! card record deleted successfully")
        }
    }
    
    // MARK: - Get Yu-Gi-Oh! Card Details
    
    func getYuGiOhCardDetails(for cardIds: [String]) async throws -> [YuGiOhCard] {
        guard !cardIds.isEmpty else { return [] }
        
        print("📋 Fetching Yu-Gi-Oh! card details for \(cardIds.count) cards")
        
        let yugiohCards: [YuGiOhCard] = try await supabase
            .from("ygo_cards")
            .select("*")
            .in("id", values: cardIds)
            .execute()
            .value
        
        print("✅ Retrieved \(yugiohCards.count) Yu-Gi-Oh! card details")
        return yugiohCards
    }
    
    // MARK: - Clear All Yu-Gi-Oh! Cards for User
    
    func clearAllYuGiOhCards() async throws {
        print("🧹 Clearing all Yu-Gi-Oh! cards for user...")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        try await supabase
            .from("user_ygo_cards")
            .delete()
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
        
        print("✅ All Yu-Gi-Oh! cards cleared from Supabase")
    }
    
    // MARK: - Cleanup invalid quantities
    
    func cleanupInvalidQuantities() async throws {
        print("🧹 Cleaning up Yu-Gi-Oh! cards with invalid quantities...")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Delete any cards with qty <= 0
        try await supabase
            .from("user_ygo_cards")
            .delete()
            .eq("user_id", value: currentUser.id.uuidString)
            .lte("qty", value: 0)
            .execute()
        
        print("✅ Invalid quantity records cleaned up")
    }
}