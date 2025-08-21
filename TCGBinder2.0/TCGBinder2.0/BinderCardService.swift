//
//  BinderCardService.swift
//  TCGBinder2.0
//
//  Service for managing binder-specific card storage using user_binder_cards table
//

import Foundation
import SwiftUI
import Supabase

@MainActor
class BinderCardService: ObservableObject {
    
    // MARK: - Add Card to Binder
    
    func addCardToBinder(binderId: String, cardId: String, cardType: TCGType, qty: Int = 1) async throws {
        print("➕ Adding card to binder...")
        print("   - Binder ID: \(binderId)")
        print("   - Card ID: \(cardId)")
        print("   - Card Type: \(cardType.rawValue)")
        print("   - Quantity: \(qty)")
        
        // Get the UUID of the card from the appropriate table
        let cardUUID = try await getCardUUID(cardId: cardId, cardType: cardType)
        print("   - Card UUID: \(cardUUID)")
        
        // Check if card already exists in this binder
        let existingCards: [UserBinderCard] = try await supabase
            .from("user_binder_cards")
            .select("*")
            .eq("binder_id", value: binderId)
            .eq("card_id", value: cardUUID)
            .execute()
            .value
        
        if let existingCard = existingCards.first {
            // Card exists, increment quantity
            let currentQty = existingCard.qty
            let newQty = currentQty + qty
            print("📈 Card exists, incrementing qty from \(currentQty) to \(newQty)")
            
            try await supabase
                .from("user_binder_cards")
                .update(UpdateUserBinderCardQtyParams(qty: newQty))
                .eq("binder_id", value: binderId)
                .eq("card_id", value: cardUUID)
                .execute()
            
            print("✅ Card quantity incremented successfully")
        } else {
            // Card doesn't exist, create new entry
            print("🆕 Card doesn't exist in binder, creating new entry with qty = \(qty)")
            
            let cardData = CreateUserBinderCardParams(
                binderId: binderId,
                cardId: cardUUID,
                qty: qty,
                notes: nil,
                condition: "Near Mint" // Default condition
            )
            
            try await supabase
                .from("user_binder_cards")
                .insert(cardData)
                .execute()
            
            print("✅ Card added to binder successfully")
        }
    }
    
    // MARK: - Load Cards for Specific Binder
    
    func loadCardsForBinder(binderId: String) async throws -> [UserBinderCard] {
        print("📥 Loading cards for binder: \(binderId)")
        
        let binderCards: [UserBinderCard] = try await supabase
            .from("user_binder_cards")
            .select("*")
            .eq("binder_id", value: binderId)
            .execute()
            .value
        
        print("✅ Loaded \(binderCards.count) cards for binder")
        return binderCards
    }
    
    // MARK: - Remove Card from Binder
    
    func removeCardFromBinder(binderId: String, cardId: String, cardType: TCGType) async throws {
        print("➖ Removing card from binder...")
        print("   - Binder ID: \(binderId)")
        print("   - Card ID: \(cardId)")
        
        // Get the UUID of the card
        let cardUUID = try await getCardUUID(cardId: cardId, cardType: cardType)
        
        // Check if card exists in this binder
        let existingCards: [UserBinderCard] = try await supabase
            .from("user_binder_cards")
            .select("*")
            .eq("binder_id", value: binderId)
            .eq("card_id", value: cardUUID)
            .execute()
            .value
        
        guard let existingCard = existingCards.first else {
            print("⚠️ Card not found in binder, nothing to remove")
            return
        }
        
        let currentQty = existingCard.qty
        
        if currentQty > 1 {
            // Card has multiple copies, decrement quantity
            let newQty = currentQty - 1
            print("📉 Card has \(currentQty) copies, decrementing to \(newQty)")
            
            try await supabase
                .from("user_binder_cards")
                .update(UpdateUserBinderCardQtyParams(qty: newQty))
                .eq("binder_id", value: binderId)
                .eq("card_id", value: cardUUID)
                .execute()
            
            print("✅ Card quantity decremented successfully")
        } else {
            // Card has only 1 copy, delete the record entirely
            print("🗑️ Card has only 1 copy, deleting record entirely")
            
            try await supabase
                .from("user_binder_cards")
                .delete()
                .eq("binder_id", value: binderId)
                .eq("card_id", value: cardUUID)
                .execute()
            
            print("✅ Card record deleted successfully")
        }
    }
    
    // MARK: - Get Card Details for Multiple Cards
    
    func getCardDetails(for binderCards: [UserBinderCard], cardType: TCGType) async throws -> [OnePieceCard] {
        guard !binderCards.isEmpty else { return [] }
        
        let cardIds = binderCards.map { $0.cardId }
        print("📋 Fetching card details for \(cardIds.count) \(cardType.rawValue) cards")
        
        switch cardType {
        case .pokemon:
            let pokemonCards: [PokemonCardResponse] = try await supabase
                .from("pkm_cards")
                .select("*")
                .in("id", values: cardIds)
                .execute()
                .value
            
            print("✅ Retrieved \(pokemonCards.count) Pokemon card details")
            return pokemonCards.map { adaptPokemonCardToInternalFormat($0) }
            
        case .yugioh:
            let yugiohCards: [YuGiOhCard] = try await supabase
                .from("ygo_cards")
                .select("*")
                .in("id", values: cardIds)
                .execute()
                .value
            
            print("✅ Retrieved \(yugiohCards.count) Yu-Gi-Oh! card details")
            return yugiohCards.map { adaptYuGiOhCardToInternalFormat($0) }
            
        case .onePiece:
            let onePieceCards: [OnePieceCardResponse] = try await supabase
                .from("op_cards")
                .select("*")
                .in("id", values: cardIds)
                .execute()
                .value
            
            print("✅ Retrieved \(onePieceCards.count) One Piece card details")
            return onePieceCards.map { adaptOnePieceCardToInternalFormat($0) }
        }
    }
    
    // MARK: - Clear All Cards from Binder
    
    func clearAllCardsFromBinder(binderId: String) async throws {
        print("🧹 Clearing all cards from binder: \(binderId)")
        
        try await supabase
            .from("user_binder_cards")
            .delete()
            .eq("binder_id", value: binderId)
            .execute()
        
        print("✅ All cards cleared from binder")
    }
    
    // MARK: - Clear All Cards for All User's Binders
    
    func clearAllBinderCards() async throws {
        print("🧹 Clearing all binder cards for user...")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Create a simple struct for just getting binder IDs
        struct BinderIdResult: Codable {
            let id: String
        }
        
        // Get all user's binder IDs first
        let binderIdResults: [BinderIdResult] = try await supabase
            .from("user_binders")
            .select("id")
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        let binderIds = binderIdResults.map { $0.id }
        
        if !binderIds.isEmpty {
            try await supabase
                .from("user_binder_cards")
                .delete()
                .in("binder_id", values: binderIds)
                .execute()
            
            print("✅ Cleared cards from \(binderIds.count) binders")
        } else {
            print("ℹ️ No binders found for user")
        }
        
        print("✅ All binder cards cleared from Supabase")
    }
    
    // MARK: - Helper Methods
    
    private func getCardUUID(cardId: String, cardType: TCGType) async throws -> String {
        print("🔍 Looking up card UUID for: \(cardId) in \(cardType.rawValue)")
        
        // Create a simple struct for the all_cards lookup
        struct AllCardLookup: Codable {
            let id: String
        }
        
        // Determine the game value for the query
        let gameValue: String
        switch cardType {
        case .pokemon:
            gameValue = "pokemon"
        case .yugioh:
            gameValue = "yugioh"
        case .onePiece:
            gameValue = "one_piece"
        }
        
        print("🔍 Querying: game='\(gameValue)', code='\(cardId)'")
        
        let cards: [AllCardLookup]
        do {
            cards = try await supabase
                .from("all_cards")
                .select("id")
                .eq("game", value: gameValue)
                .eq("code", value: cardId)  // Use 'code' column instead of 'source_id'
                .execute()
                .value
            
            print("🔍 Query returned \(cards.count) results")
        } catch {
            print("❌ Error during Supabase query: \(error)")
            throw error
        }
        
        guard let card = cards.first else {
            // Let's check if the card exists with a different game value
            print("🔍 Card not found with game='\(gameValue)'. Checking all game values for source_id='\(cardId)'...")
            
            let allMatches: [AllCardLookup] = try await supabase
                .from("all_cards")
                .select("id")
                .eq("source_id", value: cardId)
                .execute()
                .value
            
            print("🔍 Found \(allMatches.count) cards with source_id='\(cardId)' across all games")
            
            throw NSError(domain: "CardNotFound", code: 404, userInfo: [NSLocalizedDescriptionKey: "\(cardType.rawValue) card not found in all_cards with source_id: \(cardId) and game: \(gameValue)"])
        }
        
        print("✅ Found card UUID: \(card.id)")
        return card.id
    }
    
    // MARK: - Helper Methods for Card Conversion
    
    private func adaptPokemonCardToInternalFormat(_ pokemonCard: PokemonCardResponse) -> OnePieceCard {
        return OnePieceCard(
            cardName: pokemonCard.name,
            rarity: pokemonCard.rarity,
            cardCost: nil,
            cardPower: pokemonCard.hp != nil ? String(pokemonCard.hp!) : nil,
            counterAmount: nil,
            cardColor: pokemonCard.types?.first,
            cardType: pokemonCard.types?.joined(separator: ", "),
            cardText: pokemonCard.abilities?.first?.text,
            setId: pokemonCard.set_id,
            cardSetId: pokemonCard.id,
            cardImage: pokemonCard.image_url,
            attribute: pokemonCard.subtypes?.joined(separator: ", "),
            inventoryPrice: pokemonCard.tcgplayer_market_price,
            marketPrice: pokemonCard.tcgplayer_market_price,
            setName: pokemonCard.set_id, // TODO: Add set mapping if needed
            subTypes: pokemonCard.subtypes?.joined(separator: ", "),
            life: nil,
            dateScrapped: nil,
            cardImageId: pokemonCard.id,
            trigger: nil
        )
    }
    
    private func adaptYuGiOhCardToInternalFormat(_ yugiohCard: YuGiOhCard) -> OnePieceCard {
        return OnePieceCard(
            cardName: yugiohCard.name,
            rarity: nil,
            cardCost: nil,
            cardPower: nil,
            counterAmount: nil,
            cardColor: nil,
            cardType: yugiohCard.type,
            cardText: yugiohCard.description,
            setId: yugiohCard.frameType,
            cardSetId: yugiohCard.id ?? "unknown",
            cardImage: yugiohCard.imageUrl,
            attribute: yugiohCard.frameType,
            inventoryPrice: nil,
            marketPrice: nil,
            setName: yugiohCard.frameType,
            subTypes: yugiohCard.type,
            life: nil,
            dateScrapped: nil,
            cardImageId: yugiohCard.id ?? "unknown",
            trigger: nil
        )
    }
    
    private func adaptOnePieceCardToInternalFormat(_ onePieceCard: OnePieceCardResponse) -> OnePieceCard {
        return OnePieceCard(
            cardName: onePieceCard.name,
            rarity: onePieceCard.rarity,
            cardCost: onePieceCard.card_cost?.stringValue,
            cardPower: onePieceCard.card_power?.stringValue,
            counterAmount: onePieceCard.counter_amount,
            cardColor: onePieceCard.card_color,
            cardType: onePieceCard.card_type,
            cardText: onePieceCard.card_text,
            setId: onePieceCard.set_id,
            cardSetId: onePieceCard.card_set_id,
            cardImage: onePieceCard.image_url,
            attribute: onePieceCard.attribute,
            inventoryPrice: onePieceCard.inventory_price,
            marketPrice: onePieceCard.market_price,
            setName: onePieceCard.set_name,
            subTypes: onePieceCard.sub_types,
            life: onePieceCard.life != nil ? String(onePieceCard.life!) : nil,
            dateScrapped: onePieceCard.date_scraped,
            cardImageId: onePieceCard.card_image_id,
            trigger: onePieceCard.trigger
        )
    }
}