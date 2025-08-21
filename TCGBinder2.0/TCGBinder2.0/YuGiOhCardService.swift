//
//  YuGiOhCardService.swift
//  TCGBinder2.0
//
//  Service for fetching Yu-Gi-Oh! cards from Supabase
//

import Foundation
import Supabase

@MainActor
class YuGiOhCardService: ObservableObject {
    
    // MARK: - Search YuGiOh Cards
    
    func searchYuGiOhCards(query: String, limit: Int = 20) async throws -> [YuGiOhCard] {
        let cards: [YuGiOhCard] = try await supabase
            .from("ygo_cards")
            .select("*")
            .ilike("name", pattern: "%\(query)%")
            .limit(limit)
            .execute()
            .value
        
        return cards
    }
    
    // MARK: - Get YuGiOh Card Details
    
    func getYuGiOhCardDetails(for cardIds: [Int]) async throws -> [YuGiOhCard] {
        guard !cardIds.isEmpty else { return [] }
        
        let cards: [YuGiOhCard] = try await supabase
            .from("ygo_cards")
            .select("*")
            .in("id", values: cardIds)
            .execute()
            .value
        
        return cards
    }
    
    // MARK: - Get Random YuGiOh Cards
    
    func getRandomYuGiOhCards(limit: Int = 10) async throws -> [YuGiOhCard] {
        let cards: [YuGiOhCard] = try await supabase
            .from("ygo_cards")
            .select("*")
            .limit(limit)
            .execute()
            .value
        
        return cards
    }
}