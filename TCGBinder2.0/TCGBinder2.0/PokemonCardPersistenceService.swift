//
//  PokemonCardPersistenceService.swift
//  TCGBinder2.0
//
//  Pokemon card persistence service for saving/loading user cards to/from Supabase
//

import Foundation
import Supabase

@MainActor
class PokemonCardPersistenceService: ObservableObject {
    
    // MARK: - Add Pokemon Card (increment quantity)
    
    func addPokemonCard(cardId: String) async throws {
        
        print("➕ Adding Pokemon card to Supabase...")
        print("   - Card ID: \(cardId)")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Check if card already exists for this user
        let existingCards: [UserPokemonCard] = try await supabase
            .from("user_pkm_cards")
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
                .from("user_pkm_cards")
                .update(UpdateUserPokemonCardQtyParams(qty: newQty))
                .eq("user_id", value: currentUser.id.uuidString)
                .eq("card_id", value: cardId)
                .execute()
            
            print("✅ Pokemon card quantity incremented successfully")
        } else {
            // Card doesn't exist, create new with qty = 1
            print("🆕 Card doesn't exist, creating new with qty = 1")
            
            let cardData = CreateUserPokemonCardParams(
                userId: currentUser.id.uuidString,
                cardId: cardId,
                qty: 1
            )
            
            try await supabase
                .from("user_pkm_cards")
                .insert(cardData)
                .execute()
            
            print("✅ Pokemon card created successfully")
        }
    }
    
    // MARK: - Load Pokemon Cards from USER_PKM_CARDS table
    
    func loadPokemonCards() async throws -> [UserPokemonCard] {
        print("📥 Loading Pokemon cards from Supabase...")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        let userCards: [UserPokemonCard] = try await supabase
            .from("user_pkm_cards")
            .select("*")
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        print("✅ Loaded \(userCards.count) Pokemon cards from Supabase")
        return userCards
    }
    
    // MARK: - Remove Pokemon Card (decrement quantity)
    
    func removePokemonCard(cardId: String) async throws {
        print("➖ Removing Pokemon card from Supabase...")
        print("   - Card ID: \(cardId)")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Check if card exists for this user
        let existingCards: [UserPokemonCard] = try await supabase
            .from("user_pkm_cards")
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
                .from("user_pkm_cards")
                .update(UpdateUserPokemonCardQtyParams(qty: newQty))
                .eq("user_id", value: currentUser.id.uuidString)
                .eq("card_id", value: cardId)
                .execute()
            
            print("✅ Pokemon card quantity decremented successfully")
        } else {
            // Card has only 1 copy, delete the record entirely
            print("🗑️ Card has only 1 copy, deleting record entirely")
            
            try await supabase
                .from("user_pkm_cards")
                .delete()
                .eq("user_id", value: currentUser.id.uuidString)
                .eq("card_id", value: cardId)
                .execute()
            
            print("✅ Pokemon card record deleted successfully")
        }
    }
    
    // MARK: - Get Pokemon Card Details
    
    func getPokemonCardDetails(for cardIds: [String]) async throws -> [PokemonCardResponse] {
        guard !cardIds.isEmpty else { return [] }
        
        print("📋 Fetching Pokemon card details for \(cardIds.count) cards")
        
        let pokemonCards: [PokemonCardResponse] = try await supabase
            .from("pkm_cards")
            .select("*")
            .in("id", values: cardIds)
            .execute()
            .value
        
        print("✅ Retrieved \(pokemonCards.count) Pokemon card details")
        return pokemonCards
    }
    
    // MARK: - Clear All Pokemon Cards for User
    
    func clearAllPokemonCards() async throws {
        print("🧹 Clearing all Pokemon cards for user...")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        try await supabase
            .from("user_pkm_cards")
            .delete()
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
        
        print("✅ All Pokemon cards cleared from Supabase")
    }
    
    // MARK: - Cleanup invalid quantities
    
    func cleanupInvalidQuantities() async throws {
        print("🧹 Cleaning up Pokemon cards with invalid quantities...")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Delete any cards with qty <= 0
        try await supabase
            .from("user_pkm_cards")
            .delete()
            .eq("user_id", value: currentUser.id.uuidString)
            .lte("qty", value: 0)
            .execute()
        
        print("✅ Invalid quantity records cleaned up")
    }
}