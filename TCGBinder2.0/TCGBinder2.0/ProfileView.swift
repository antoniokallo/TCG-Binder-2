//
//  ProfileView.swift
//  TCGBinder2.0
//
//  Created by Edward Kogos on 8/15/25.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
  @State var username = ""
  @State var fullName = ""
  @State var website = ""
  @State var bio = ""
  @State var userEmail = ""
  @State var avatarUrl = ""
  @State var isLoading = false
  @State var isUpdating = false
  @State var showingImagePicker = false
  @State var selectedPhoto: PhotosPickerItem?
  @State var profileImage: UIImage?
  @StateObject private var profileService = ProfileService()
  @Environment(\.dismiss) private var dismiss
  let selectedBackground: BackgroundType

  var body: some View {
    NavigationView {
      ZStack {
        AppBackground(selectedBackground: selectedBackground)
          .ignoresSafeArea()
        
        ScrollView {
          VStack(spacing: 24) {
            // Profile Header
            profileHeader
            
            // User Info Cards
            userInfoSection
            
            // Actions Section
            actionsSection
            
            Spacer(minLength: 20)
          }
          .padding()
        }
      }
      .navigationTitle("Profile")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .task {
      await getInitialProfile()
    }
    .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhoto, matching: .images)
    .onChange(of: selectedPhoto) { oldValue, newValue in
      Task {
        await loadSelectedPhoto()
      }
    }
  }
  
  private var profileHeader: some View {
    VStack(spacing: 16) {
      // Profile Photo
      Button {
        showingImagePicker = true
      } label: {
        ZStack {
          Circle()
            .fill(Color("BinderGreen").opacity(0.3))
            .frame(width: 100, height: 100)
          
          if let profileImage {
            Image(uiImage: profileImage)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 100, height: 100)
              .clipShape(Circle())
          } else if !avatarUrl.isEmpty {
            AsyncImage(url: URL(string: avatarUrl)) { image in
              image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } placeholder: {
              Circle()
                .fill(Color("BinderGreen").opacity(0.3))
                .frame(width: 100, height: 100)
                .overlay(
                  ProgressView()
                    .tint(.white)
                )
            }
          } else if fullName.isEmpty && username.isEmpty {
            Image(systemName: "person.fill")
              .font(.system(size: 40))
              .foregroundStyle(.secondary)
          } else {
            Text(profileInitials)
              .font(.system(size: 36, weight: .medium))
              .foregroundStyle(.primary)
          }
          
          // Camera overlay
          Circle()
            .fill(Color.black.opacity(0.3))
            .frame(width: 100, height: 100)
            .overlay(
              Image(systemName: "camera.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .opacity(0.8)
            )
            .opacity(profileImage != nil || !avatarUrl.isEmpty ? 0.7 : 1.0)
        }
        .overlay(
          Circle()
            .stroke(Color.black.opacity(0.1), lineWidth: 2)
        )
      }
      
      VStack(spacing: 4) {
        Text(displayName)
          .font(.title2.weight(.semibold))
          .foregroundStyle(.primary)
        
        Text(userEmail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical)
  }
  
  private var userInfoSection: some View {
    VStack(spacing: 16) {
      InfoCard(
        icon: "person.fill",
        title: "Username",
        value: $username,
        placeholder: "Enter username"
      )
      
      InfoCard(
        icon: "person.text.rectangle.fill",
        title: "Full Name",
        value: $fullName,
        placeholder: "Enter full name"
      )
      
      InfoCard(
        icon: "globe",
        title: "Website",
        value: $website,
        placeholder: "Enter website URL"
      )
      
      InfoCard(
        icon: "text.quote",
        title: "Bio",
        value: $bio,
        placeholder: "Tell us about yourself"
      )
    }
  }
  
  private var actionsSection: some View {
    VStack(spacing: 12) {
      Button {
        updateProfileButtonTapped()
      } label: {
        HStack {
          if isUpdating {
            ProgressView()
              .scaleEffect(0.8)
              .tint(.white)
          } else {
            Image(systemName: "checkmark.circle.fill")
          }
          Text("Update Profile")
        }
        .font(.headline.weight(.semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .disabled(isUpdating)
      
      Button {
        signOutTapped()
      } label: {
        HStack {
          Image(systemName: "arrow.right.square.fill")
          Text("Sign Out")
        }
        .font(.headline.weight(.semibold))
        .foregroundColor(.red)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
      }
    }
  }
  
  private var displayName: String {
    if !fullName.isEmpty {
      return fullName
    } else if !username.isEmpty {
      return username
    } else {
      return "User"
    }
  }
  
  private var profileInitials: String {
    let name = displayName
    let components = name.components(separatedBy: " ")
    
    if components.count >= 2 {
      let firstInitial = String(components[0].prefix(1))
      let lastInitial = String(components[1].prefix(1))
      return (firstInitial + lastInitial).uppercased()
    } else {
      return String(name.prefix(2)).uppercased()
    }
  }
  
  private func signOutTapped() {
    Task {
      try? await supabase.auth.signOut()
      await MainActor.run {
        dismiss()
      }
    }
  }

  func getInitialProfile() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
      let currentUser = try await supabase.auth.session.user
      
      // Set user email from auth
      await MainActor.run {
        self.userEmail = currentUser.email ?? "No email"
      }

      // Ensure profile exists
      try await profileService.createProfileIfNeeded(
        userId: currentUser.id.uuidString,
        email: currentUser.email ?? ""
      )

      // Load profile
      let profile = try await profileService.loadProfile(userId: currentUser.id.uuidString)

      await MainActor.run {
        self.username = profile.username ?? ""
        self.fullName = profile.fullName ?? ""
        self.website = profile.website ?? ""
        self.bio = profile.bio ?? ""
        self.avatarUrl = profile.avatarUrl ?? ""
      }

    } catch {
      debugPrint("Error loading profile: \(error)")
      // If profile doesn't exist, that's okay - user can create one
    }
  }

  func updateProfileButtonTapped() {
    Task {
      isUpdating = true
      defer { 
        Task { @MainActor in
          isUpdating = false
        }
      }
      
      do {
        let currentUser = try await supabase.auth.session.user

        try await profileService.updateProfile(
          userId: currentUser.id.uuidString,
          username: username,
          fullName: fullName,
          website: website,
          bio: bio,
          avatarUrl: avatarUrl.isEmpty ? nil : avatarUrl
        )
          
        debugPrint("Profile updated successfully")
      } catch {
        debugPrint("Error updating profile: \(error)")
      }
    }
  }
  
  private func loadSelectedPhoto() async {
    guard let selectedPhoto else { return }
    
    do {
      if let data = try await selectedPhoto.loadTransferable(type: Data.self) {
        if let image = UIImage(data: data) {
          await MainActor.run {
            self.profileImage = image
          }
          
          // Upload the photo
          let currentUser = try await supabase.auth.session.user
          let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
          
          let uploadedUrl = try await profileService.uploadProfilePhoto(
            userId: currentUser.id.uuidString,
            imageData: imageData
          )
          
          await MainActor.run {
            self.avatarUrl = uploadedUrl
          }
          
          // Update profile with new avatar URL
          try await profileService.updateAvatarUrl(
            userId: currentUser.id.uuidString,
            avatarUrl: uploadedUrl
          )
          
          debugPrint("Profile photo uploaded successfully: \(uploadedUrl)")
        }
      }
    } catch {
      debugPrint("Error loading selected photo: \(error)")
    }
  }
}

// MARK: - InfoCard Component
struct InfoCard: View {
  let icon: String
  let title: String
  @Binding var value: String
  let placeholder: String
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(width: 16)
        
        Text(title)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
      }
      
      TextField(placeholder, text: $value)
        .textFieldStyle(.plain)
        .font(.body)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .textInputAutocapitalization(title == "Website" ? .never : .words)
        .autocorrectionDisabled(title == "Website" || title == "Username")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }
}
