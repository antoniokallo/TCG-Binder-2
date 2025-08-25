//
//  FriendsView.swift
//  TCGBinder2.0
//
//  View for managing friends, friend requests, and social features
//

import SwiftUI

struct FriendsView: View {
    @StateObject private var friendService = FriendService()
    @State private var friends: [UserSearchResult] = []
    @State private var pendingRequests: [FriendRequest] = []
    @State private var sentRequests: [FriendRequest] = []
    @State private var isLoadingFriends = true
    @State private var isLoadingRequests = true
    @State private var currentUserId = ""
    @State private var showingUserSearch = false
    @AppStorage("selectedBackground") private var selectedBackground: BackgroundType = .potential
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground(selectedBackground: selectedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Add Friends Button
                        Button {
                            showingUserSearch = true
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Find Friends")
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                        
                        // Friend Requests Section
                        if !pendingRequests.isEmpty {
                            friendRequestsSection
                        }
                        
                        // Friends List Section
                        friendsListSection
                        
                        // Sent Requests Section (collapsed by default)
                        if !sentRequests.isEmpty {
                            sentRequestsSection
                        }
                        
                        Spacer(minLength: 20)
                    }
                }
                .refreshable {
                    await loadAllData()
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingUserSearch) {
            UserSearchView()
        }
        .task {
            await loadCurrentUser()
            await loadAllData()
        }
    }
    
    // MARK: - Friend Requests Section
    
    private var friendRequestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.orange)
                Text("Friend Requests")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(pendingRequests.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            
            if isLoadingRequests {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(pendingRequests) { request in
                        FriendRequestCard(
                            request: request,
                            friendService: friendService,
                            onRequestHandled: {
                                Task {
                                    await loadAllData()
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Friends List Section
    
    private var friendsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.green)
                Text("My Friends")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                if !friends.isEmpty {
                    Text("\(friends.count)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
            
            if isLoadingFriends {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if friends.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No friends yet")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Find and add friends to share your collections")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(friends) { friend in
                        FriendCard(
                            user: friend,
                            currentUserId: currentUserId,
                            friendService: friendService
                        )
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Sent Requests Section
    
    private var sentRequestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.blue)
                Text("Sent Requests")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(sentRequests.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            
            LazyVStack(spacing: 12) {
                ForEach(sentRequests) { request in
                    SentRequestCard(request: request, friendService: friendService)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Helper Functions
    
    private func loadCurrentUser() async {
        do {
            let user = try await supabase.auth.session.user
            await MainActor.run {
                self.currentUserId = user.id.uuidString
            }
        } catch {
            debugPrint("Error loading current user: \(error)")
        }
    }
    
    private func loadAllData() async {
        guard !currentUserId.isEmpty else { return }
        
        async let friendsTask = loadFriends()
        async let requestsTask = loadFriendRequests()
        async let sentRequestsTask = loadSentRequests()
        
        await friendsTask
        await requestsTask
        await sentRequestsTask
    }
    
    private func loadFriends() async {
        do {
            let loadedFriends = try await friendService.getFriends(for: currentUserId)
            await MainActor.run {
                self.friends = loadedFriends
                self.isLoadingFriends = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingFriends = false
            }
            debugPrint("Error loading friends: \(error)")
        }
    }
    
    private func loadFriendRequests() async {
        do {
            let requests = try await friendService.getFriendRequestsReceived(for: currentUserId)
            await MainActor.run {
                self.pendingRequests = requests
                self.isLoadingRequests = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingRequests = false
            }
            debugPrint("Error loading friend requests: \(error)")
        }
    }
    
    private func loadSentRequests() async {
        do {
            let requests = try await friendService.getFriendRequestsSent(from: currentUserId)
            await MainActor.run {
                self.sentRequests = requests.filter { $0.status == FriendRequestStatus.pending.rawValue }
            }
        } catch {
            debugPrint("Error loading sent requests: \(error)")
        }
    }
}

// MARK: - Friend Request Card

struct FriendRequestCard: View {
    let request: FriendRequest
    let friendService: FriendService
    let onRequestHandled: () -> Void
    
    @State private var requesterUser: UserSearchResult?
    @State private var isLoading = true
    @State private var isAccepting = false
    @State private var isDeclining = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Photo
            if let user = requesterUser {
                if let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                    }
                } else {
                    Circle()
                        .fill(Color("BinderGreen").opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(userInitials)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                        )
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                if let user = requesterUser {
                    Text(displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    if let username = user.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("wants to be friends")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                Button {
                    Task {
                        await declineRequest()
                    }
                } label: {
                    if isDeclining {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.red)
                    } else {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.red)
                    }
                }
                .frame(width: 32, height: 32)
                .background(Color.red.opacity(0.1))
                .clipShape(Circle())
                .disabled(isAccepting || isDeclining)
                
                Button {
                    Task {
                        await acceptRequest()
                    }
                } label: {
                    if isAccepting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.green)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.green)
                    }
                }
                .frame(width: 32, height: 32)
                .background(Color.green.opacity(0.1))
                .clipShape(Circle())
                .disabled(isAccepting || isDeclining)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .task {
            await loadRequesterInfo()
        }
    }
    
    private var displayName: String {
        guard let user = requesterUser else { return "Unknown User" }
        
        if let fullName = user.fullName, !fullName.isEmpty {
            return fullName
        } else if let username = user.username, !username.isEmpty {
            return username
        } else {
            return "TCG Collector"
        }
    }
    
    private var userInitials: String {
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
    
    private func loadRequesterInfo() async {
        do {
            let user = try await friendService.getUserById(request.requesterId)
            await MainActor.run {
                self.requesterUser = user
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            debugPrint("Error loading requester info: \(error)")
        }
    }
    
    private func acceptRequest() async {
        guard let requestId = request.id else { return }
        
        await MainActor.run {
            self.isAccepting = true
        }
        
        do {
            try await friendService.updateFriendRequest(requestId: requestId, status: .accepted)
            await MainActor.run {
                self.isAccepting = false
            }
            onRequestHandled()
        } catch {
            await MainActor.run {
                self.isAccepting = false
            }
            debugPrint("Error accepting friend request: \(error)")
        }
    }
    
    private func declineRequest() async {
        guard let requestId = request.id else { return }
        
        await MainActor.run {
            self.isDeclining = true
        }
        
        do {
            try await friendService.updateFriendRequest(requestId: requestId, status: .declined)
            await MainActor.run {
                self.isDeclining = false
            }
            onRequestHandled()
        } catch {
            await MainActor.run {
                self.isDeclining = false
            }
            debugPrint("Error declining friend request: \(error)")
        }
    }
}

// MARK: - Friend Card

struct FriendCard: View {
    let user: UserSearchResult
    let currentUserId: String
    let friendService: FriendService
    @State private var showingProfile = false
    
    var body: some View {
        Button {
            showingProfile = true
        } label: {
            HStack(spacing: 16) {
                // Profile Photo
                if let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                    }
                } else {
                    Circle()
                        .fill(Color("BinderGreen").opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(userInitials)
                                .font(.title3.weight(.medium))
                                .foregroundColor(.primary)
                        )
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let username = user.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingProfile) {
            UserProfileView(user: user, currentUserId: currentUserId, friendService: friendService)
        }
    }
    
    private var displayName: String {
        if let fullName = user.fullName, !fullName.isEmpty {
            return fullName
        } else if let username = user.username, !username.isEmpty {
            return username
        } else {
            return "TCG Collector"
        }
    }
    
    private var userInitials: String {
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
}

// MARK: - Sent Request Card

struct SentRequestCard: View {
    let request: FriendRequest
    let friendService: FriendService
    
    @State private var addresseeUser: UserSearchResult?
    @State private var isLoading = true
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Photo
            if let user = addresseeUser {
                if let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                    }
                } else {
                    Circle()
                        .fill(Color("BinderGreen").opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(userInitials)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                        )
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                if let user = addresseeUser {
                    Text(displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    if let username = user.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status
            Text("Pending")
                .font(.caption.weight(.medium))
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .task {
            await loadAddresseeInfo()
        }
    }
    
    private var displayName: String {
        guard let user = addresseeUser else { return "Unknown User" }
        
        if let fullName = user.fullName, !fullName.isEmpty {
            return fullName
        } else if let username = user.username, !username.isEmpty {
            return username
        } else {
            return "TCG Collector"
        }
    }
    
    private var userInitials: String {
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
    
    private func loadAddresseeInfo() async {
        do {
            let user = try await friendService.getUserById(request.addresseeId)
            await MainActor.run {
                self.addresseeUser = user
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            debugPrint("Error loading addressee info: \(error)")
        }
    }
}