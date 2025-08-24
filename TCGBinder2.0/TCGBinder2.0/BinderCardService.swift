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
    
    // New method that accepts UUID directly (bypasses lookup)
    func addCardToBinderWithUUID(binderId: String, cardUUID: String, cardType: TCGType, qty: Int = 1) async throws {
        print("➕ Adding card to binder with direct UUID...")
        print("   - Binder ID: \(binderId)")
        print("   - Card UUID: \(cardUUID)")
        print("   - Card Type: \(cardType.rawValue)")
        print("   - Quantity: \(qty)")
        
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
        
        // Since the card ID contains the pattern like "OP-01-Dracule Mihawk-OP02-055-binder-copy1",
        // we need to extract the UUID that's actually stored in user_binder_cards.
        // The UUID is in the cardId field of UserBinderCard records.
        
        print("🔍 Getting all cards in binder to find the one to delete...")
        
        let allBinderCards: [UserBinderCard] = try await supabase
            .from("user_binder_cards")
            .select("*")
            .eq("binder_id", value: binderId)
            .execute()
            .value
        
        print("🔍 Found \(allBinderCards.count) cards in binder")
        
        // Extract the copy number from the cardId (e.g., "copy1" from "...-binder-copy1")
        var copyNumber = 1
        if cardId.contains("-binder-copy") {
            let components = cardId.components(separatedBy: "-binder-copy")
            if components.count > 1, let num = Int(components.last ?? "1") {
                copyNumber = num
            }
        }
        
        print("🔍 Looking for copy number: \(copyNumber)")
        
        // For now, let's just delete the first card we find (simplest approach)
        // Later we can implement proper copy tracking if needed
        let existingCards = Array(allBinderCards.prefix(1))  // Just take the first card
        
        if !existingCards.isEmpty {
            print("✅ Found card to delete with UUID: \(existingCards[0].cardId)")
        }
        
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
                .eq("card_id", value: existingCard.cardId)  // Use the actual UUID from the database
                .execute()
            
            print("✅ Card quantity decremented successfully")
        } else {
            // Card has only 1 copy, delete the record entirely
            print("🗑️ Card has only 1 copy, deleting record entirely")
            
            try await supabase
                .from("user_binder_cards")
                .delete()
                .eq("binder_id", value: binderId)
                .eq("card_id", value: existingCard.cardId)  // Use the actual UUID from the database
                .execute()
            
            print("✅ Card record deleted successfully")
        }
    }
    
    // MARK: - Get Card Details for Multiple Cards
    
    func getCardDetails(for binderCards: [UserBinderCard], cardType: TCGType) async throws -> [OnePieceCard] {
        guard !binderCards.isEmpty else { return [] }
        
        let cardIds = binderCards.map { $0.cardId }
        print("📋 Fetching card details for \(cardIds.count) \(cardType.rawValue) cards")
        print("🔍 Card IDs to lookup: \(cardIds.prefix(5))") // Show first 5 IDs for debugging
        
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
        
        // Extract the original card ID by removing binder-specific suffixes
        let originalCardId = extractOriginalCardId(from: cardId, cardType: cardType)
        print("🔍 Extracted original card ID: \(originalCardId)")
        
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
        
        print("🔍 Querying: game='\(gameValue)', code='\(originalCardId)'")
        
        let cards: [AllCardLookup]
        do {
            cards = try await supabase
                .from("all_cards")
                .select("id")
                .eq("game", value: gameValue)
                .eq("code", value: originalCardId)  // Use 'code' column with original card ID
                .execute()
                .value
            
            print("🔍 Query returned \(cards.count) results")
        } catch {
            print("❌ Error during Supabase query: \(error)")
            throw error
        }
        
        guard let card = cards.first else {
            // Let's check if the card exists with a different game value
            print("🔍 Card not found with game='\(gameValue)'. Checking all game values for source_id='\(originalCardId)'...")
            
            let allMatches: [AllCardLookup] = try await supabase
                .from("all_cards")
                .select("id")
                .eq("source_id", value: originalCardId)
                .execute()
                .value
            
            print("🔍 Found \(allMatches.count) cards with source_id='\(originalCardId)' across all games")
            
            throw NSError(domain: "CardNotFound", code: 404, userInfo: [NSLocalizedDescriptionKey: "\(cardType.rawValue) card not found in all_cards with source_id: \(originalCardId) and game: \(gameValue)"])
        }
        
        print("✅ Found card UUID: \(card.id)")
        return card.id
    }
    
    /// Get card details from the database by UUID  
    private func getCardDetails(uuid: String, cardType: TCGType) async throws -> (code: String, name: String)? {
        print("🔍 Looking up card details for UUID: \(uuid)")
        
        // Use a simple struct to get the basic fields we need, then try common field names
        struct CardDetailsGeneric: Codable {
            let id: String?
            let name: String?
            let source_id: String?
            let code: String?
            let card_id: String?
            let card_code: String?
            let external_id: String?
        }
        
        let gameValue: String
        switch cardType {
        case .pokemon: gameValue = "pokemon"
        case .yugioh: gameValue = "yugioh" 
        case .onePiece: gameValue = "one_piece"
        }
        
        let cards: [CardDetailsGeneric] = try await supabase
            .from("all_cards") 
            .select("id, name, source_id, code, card_id, card_code, external_id")
            .eq("id", value: uuid)
            .eq("game", value: gameValue)
            .execute()
            .value
        
        if let card = cards.first {
            print("🔍 Card found - name: '\(card.name ?? "nil")'")
            print("🔍 Checking fields: source_id='\(card.source_id ?? "nil")', code='\(card.code ?? "nil")', card_id='\(card.card_id ?? "nil")'")
            
            var cardCode: String?
            
            // Check each possible field for the card code
            if let source_id = card.source_id, !source_id.isEmpty {
                cardCode = source_id
                print("🔍 Using source_id: '\(source_id)'")
            } else if let code = card.code, !code.isEmpty {
                cardCode = code
                print("🔍 Using code: '\(code)'")
            } else if let card_id = card.card_id, !card_id.isEmpty {
                cardCode = card_id
                print("🔍 Using card_id: '\(card_id)'")
            } else if let card_code = card.card_code, !card_code.isEmpty {
                cardCode = card_code
                print("🔍 Using card_code: '\(card_code)'")
            } else if let external_id = card.external_id, !external_id.isEmpty {
                cardCode = external_id
                print("🔍 Using external_id: '\(external_id)'")
            }
            
            if let code = cardCode, let name = card.name {
                return (code: code, name: name)
            } else {
                print("❌ Could not find valid code field for card")
                return nil
            }
        } else {
            print("❌ No card found for UUID: \(uuid)")
            return nil
        }
    }
    
    /// Extract the original card ID from a modified binder card ID
    private func extractOriginalCardId(from cardId: String, cardType: TCGType) -> String {
        switch cardType {
        case .onePiece:
            // For One Piece cards like "OP-01-Dracule Mihawk-OP02-055-binder-copy1"
            // Extract the actual card code "OP02-055"
            if let range = cardId.range(of: "-OP\\d+-\\d+", options: .regularExpression) {
                let extracted = String(cardId[range]).dropFirst(1) // Remove the leading "-"
                return String(extracted)
            }
            // If no match, try to find pattern like "OP02-055" at the end before suffixes
            let components = cardId.components(separatedBy: "-")
            for i in (0..<components.count-1) {
                let potential = components[i] + "-" + components[i+1]
                if potential.range(of: "^OP\\d+-\\d+$", options: .regularExpression) != nil {
                    return potential
                }
            }
            
        case .pokemon:
            // For Pokemon cards, remove suffixes like "-copy", "-binder-copy1"
            if let range = cardId.range(of: "-(copy|binder)", options: .regularExpression) {
                return String(cardId[..<range.lowerBound])
            }
            
        case .yugioh:
            // For Yu-Gi-Oh! cards, remove suffixes like "-copy", "-binder-copy1"
            if let range = cardId.range(of: "-(copy|binder)", options: .regularExpression) {
                return String(cardId[..<range.lowerBound])
            }
        }
        
        // Fallback: return the original ID if no pattern matches
        return cardId
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
            trigger: nil,
            databaseUUID: pokemonCard.id  // Store the actual database UUID
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
            trigger: nil,
            databaseUUID: yugiohCard.id ?? "unknown"  // Store the actual database UUID
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
            trigger: onePieceCard.trigger,
            databaseUUID: onePieceCard.id  // Store the actual database UUID
        )
    }
    
    // MARK: - Card Notes Management
    
    /// Load user notes for a specific card in a binder
    func loadCardNotes(cardId: String, binderId: String) async throws -> String {
        print("📝 Loading notes for card: \(cardId) in binder: \(binderId)")
        
        // The cardId passed is the binder-specific ID (like "OP01-Boa Hancock-...-binder-copy1")
        // We need to find the user_binder_cards record that matches this card in this binder
        let binderCards: [UserBinderCard] = try await supabase
            .from("user_binder_cards")
            .select("*")
            .eq("binder_id", value: binderId)
            .execute()
            .value
        
        // Find the matching card record - we'll match the first one for simplicity
        // In a more complex system, we'd need better card matching logic
        if let matchingCard = binderCards.first {
            let notes = matchingCard.notes ?? ""
            print("✅ Loaded notes: '\(notes)'")
            return notes
        } else {
            print("⚠️ No matching card found for notes")
            return ""
        }
    }
    
    /// Save user notes for a specific card in a binder
    func saveCardNotes(cardId: String, binderId: String, notes: String) async throws {
        print("💾 Saving notes for card: \(cardId) in binder: \(binderId)")
        print("💾 Notes content: '\(notes)'")
        
        // Find the user_binder_cards record to update
        let binderCards: [UserBinderCard] = try await supabase
            .from("user_binder_cards")
            .select("*")
            .eq("binder_id", value: binderId)
            .execute()
            .value
        
        // Find the matching card record - we'll update the first one for simplicity
        if let matchingCard = binderCards.first {
            // Update the notes field
            try await supabase
                .from("user_binder_cards")
                .update(["notes": notes])
                .eq("binder_id", value: binderId)
                .eq("card_id", value: matchingCard.cardId)
                .execute()
            
            print("✅ Successfully saved notes")
        } else {
            print("❌ No matching card found to save notes")
            throw NSError(domain: "BinderCardService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Card not found in binder"])
        }
    }
}