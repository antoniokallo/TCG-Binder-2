//
//  ProfileService.swift
//  TCGBinder2.0
//
//  Service for managing user profiles and photo uploads
//

import Foundation
import SwiftUI
import Supabase
import PhotosUI

@MainActor
class ProfileService: ObservableObject {
    
    // MARK: - Load Profile
    
    func loadProfile(userId: String) async throws -> Profile {
        let profile: Profile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        return profile
    }
    
    // MARK: - Update Profile
    
    func updateProfile(
        userId: String,
        username: String,
        fullName: String,
        website: String,
        bio: String,
        avatarUrl: String? = nil
    ) async throws {
        let params = UpdateProfileParams(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            website: website.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarUrl: avatarUrl
        )
        
        try await supabase
            .from("profiles")
            .update(params)
            .eq("id", value: userId)
            .execute()
    }
    
    // MARK: - Profile Photo Upload
    
    func uploadProfilePhoto(userId: String, imageData: Data) async throws -> String {
        let fileName = "profile_\(userId)_\(Int(Date().timeIntervalSince1970)).jpg"
        let filePath = "profiles/\(fileName)"
        
        // Upload to Supabase Storage
        try await supabase.storage
            .from("avatars")
            .upload(path: filePath, file: imageData, options: FileOptions(contentType: "image/jpeg"))
        
        // Get public URL
        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: filePath)
        
        return publicURL.absoluteString
    }
    
    // MARK: - Update Avatar URL
    
    func updateAvatarUrl(userId: String, avatarUrl: String) async throws {
        try await supabase
            .from("profiles")
            .update(["avatar_url": avatarUrl])
            .eq("id", value: userId)
            .execute()
    }
    
    // MARK: - Delete Profile Photo
    
    func deleteProfilePhoto(userId: String, avatarUrl: String) async throws {
        // Extract file path from URL
        if let url = URL(string: avatarUrl),
           let pathComponents = url.pathComponents.dropFirst(4).joined(separator: "/") as String? {
            
            try await supabase.storage
                .from("avatars")
                .remove(paths: [pathComponents])
        }
        
        // Update profile to remove avatar URL
        try await updateAvatarUrl(userId: userId, avatarUrl: "")
    }
    
    // MARK: - Create Profile (if not exists)
    
    func createProfileIfNeeded(userId: String, email: String) async throws {
        // Check if profile exists
        do {
            let _: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            // Profile exists, no need to create
        } catch {
            // Profile doesn't exist, create it
            let newProfile: [String: String?] = [
                "id": userId,
                "username": "",
                "full_name": "",
                "website": "",
                "bio": "",
                "avatar_url": nil
            ]
            
            try await supabase
                .from("profiles")
                .insert(newProfile)
                .execute()
        }
    }
}