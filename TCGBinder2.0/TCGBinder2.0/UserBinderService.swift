//
//  UserBinderService.swift
//  TCGBinder2.0
//
//  Service for managing user binders in Supabase
//

import Foundation
import SwiftUI
import Supabase

@MainActor
class UserBinderService: ObservableObject {
    
    // MARK: - Get User Binders
    
    func getUserBinders() async throws -> [UserBinder] {
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Query user_binders table for this user
        let userBinders: [UserBinder] = try await supabase
            .from("user_binders")
            .select("*")
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        return userBinders
    }
    
    // MARK: - Create New Binder
    
    func createBinder(name: String, color: Color? = nil, game: TCGType? = nil) async throws -> String {
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Get the current count of user's binders to determine the next assigned_value
        let existingBinders: [UserBinder] = try await supabase
            .from("user_binders")
            .select("*")
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
            .value
        
        // Calculate the next assigned_value (1-based counting)
        let nextAssignedValue = existingBinders.count + 1
        
        // Convert color to string, default to black if no color provided
        let colorString = color != nil ? UserBinder.colorToString(color!) : "black"
        
        // Convert game to string
        let gameString = game?.rawValue
        
        // Create the binder in user_binders table
        let createParams = CreateUserBinderParams(
            userId: currentUser.id.uuidString,
            binderType: "black", // Default binder type
            name: name,
            assignedValue: nextAssignedValue,
            binderColor: colorString,
            game: gameString
        )
        
        let response: [UserBinder] = try await supabase
            .from("user_binders")
            .insert(createParams)
            .select()
            .execute()
            .value
        
        // Return the created binder's ID
        return response.first?.id ?? ""
    }
    
    // MARK: - Delete Binder
    
    func deleteBinder(binderId: String) async throws {
        print("🗑️ UserBinderService: Attempting to delete binder with ID: \(binderId)")
        
        do {
            // Simple delete operation - just target the UUID in the id column
            try await supabase
                .from("user_binders")
                .delete()
                .eq("id", value: binderId)
                .execute()
                
            print("✅ UserBinderService: Successfully executed delete for ID: \(binderId)")
        } catch {
            print("❌ UserBinderService: Delete failed with error: \(error)")
            throw error
        }
    }
    
    // MARK: - Update Binder Name
    
    func updateBinderName(binderId: String, newName: String) async throws {
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        try await supabase
            .from("user_binders")
            .update(["name": newName])
            .eq("id", value: binderId)
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
    }
    
    // MARK: - Update Binder Color
    
    func updateBinderColor(binderId: String, newColor: Color) async throws {
        print("🎨 Updating binder color...")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        // Convert color to string
        let colorString = UserBinder.colorToString(newColor)
        
        try await supabase
            .from("user_binders")
            .update(["binder_color": colorString])
            .eq("id", value: binderId)
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
        
        print("✅ Binder color updated to: \(colorString)")
    }
    
    // MARK: - Clear All Binders for User
    
    func clearAllBinders() async throws {
        print("🧹 Clearing all binders for user...")
        
        // Get current user
        let currentUser = try await supabase.auth.session.user
        
        try await supabase
            .from("user_binders")
            .delete()
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
        
        print("✅ All binders cleared from Supabase")
    }
}
