//
//  UserSearchView.swift
//  TCGBinder2.0
//
//  View for searching users and managing friend requests
//

import SwiftUI

struct UserSearchView: View {
    @StateObject private var friendService = FriendService()
    @State private var searchText = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var currentUserId = ""
    @AppStorage("selectedBackground") private var selectedBackground: BackgroundType = .potential
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground(selectedBackground: selectedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search users by username", text: $searchText)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                Task {
                                    await performSearch()
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                                searchResults = []
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                    
                    // Search Results
                    if isSearching {
                        VStack {
                            ProgressView()
                            Text("Searching...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if searchResults.isEmpty && !searchText.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3.sequence")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text("No users found")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Try a different username")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if searchResults.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text("Search for Friends")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Enter a username to find other collectors")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(searchResults) { user in
                                    UserSearchResultCard(
                                        user: user,
                                        currentUserId: currentUserId,
                                        friendService: friendService
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Find Friends")
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
            await loadCurrentUser()
        }
        .onChange(of: searchText) { oldValue, newValue in
            if !newValue.isEmpty && newValue != oldValue {
                Task {
                    // Debounce search
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    if searchText == newValue {
                        await performSearch()
                    }
                }
            }
        }
    }
    
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
    
    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                self.searchResults = []
            }
            return
        }
        
        await MainActor.run {
            self.isSearching = true
        }
        
        do {
            let results = try await friendService.searchUsersByUsername(searchText)
            
            await MainActor.run {
                // Filter out current user from results
                self.searchResults = results.filter { $0.id != self.currentUserId }
                self.isSearching = false
            }
        } catch {
            await MainActor.run {
                self.isSearching = false
            }
            debugPrint("Error searching users: \(error)")
        }
    }
}

struct UserSearchResultCard: View {
    let user: UserSearchResult
    let currentUserId: String
    let friendService: FriendService
    
    @State private var friendRequestStatus: FriendRequestStatus?
    @State private var isLoadingStatus = true
    @State private var isSendingRequest = false
    @State private var showingProfile = false
    
    var body: some View {
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
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
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
            
            // Action Button
            if isLoadingStatus {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                friendActionButton
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            showingProfile = true
        }
        .task {
            await loadFriendRequestStatus()
        }
        .sheet(isPresented: $showingProfile) {
            UserProfileView(user: user, currentUserId: currentUserId, friendService: friendService)
        }
    }
    
    @ViewBuilder
    private var friendActionButton: some View {
        if let status = friendRequestStatus {
            switch status {
            case .pending:
                Text("Pending")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
            case .accepted:
                Button {
                    showingProfile = true
                } label: {
                    Text("Friends")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                }
            case .declined:
                Button {
                    Task {
                        await sendFriendRequest()
                    }
                } label: {
                    if isSendingRequest {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Add Friend")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .clipShape(Capsule())
                .disabled(isSendingRequest)
            }
        } else {
            Button {
                Task {
                    await sendFriendRequest()
                }
            } label: {
                if isSendingRequest {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Text("Add Friend")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .clipShape(Capsule())
            .disabled(isSendingRequest)
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
    
    private func loadFriendRequestStatus() async {
        do {
            let status = try await friendService.getFriendRequestStatus(from: currentUserId, to: user.id)
            await MainActor.run {
                self.friendRequestStatus = status
                self.isLoadingStatus = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingStatus = false
            }
            debugPrint("Error loading friend request status: \(error)")
        }
    }
    
    private func sendFriendRequest() async {
        await MainActor.run {
            self.isSendingRequest = true
        }
        
        do {
            try await friendService.sendFriendRequest(from: currentUserId, to: user.id)
            await MainActor.run {
                self.friendRequestStatus = .pending
                self.isSendingRequest = false
            }
        } catch {
            await MainActor.run {
                self.isSendingRequest = false
            }
            debugPrint("Error sending friend request: \(error)")
        }
    }
}

// MARK: - User Profile View (for viewing other users' profiles)

struct UserProfileView: View {
    let user: UserSearchResult
    let currentUserId: String
    let friendService: FriendService
    
    @State private var userBinders: [UserBinder] = []
    @State private var isLoadingBinders = false
    @State private var areFriends = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedBackground") private var selectedBackground: BackgroundType = .potential
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground(selectedBackground: selectedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        VStack(spacing: 16) {
                            // Profile Photo
                            if let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty {
                                AsyncImage(url: URL(string: avatarUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 120, height: 120)
                                        .overlay(
                                            ProgressView()
                                        )
                                }
                            } else {
                                Circle()
                                    .fill(Color("BinderGreen").opacity(0.3))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Text(userInitials)
                                            .font(.system(size: 42, weight: .medium))
                                            .foregroundColor(.primary)
                                    )
                            }
                            
                            VStack(spacing: 8) {
                                Text(displayName)
                                    .font(.title.weight(.bold))
                                    .foregroundColor(.primary)
                                
                                if let username = user.username, !username.isEmpty {
                                    Text("@\(username)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let bio = user.bio, !bio.isEmpty {
                                    Text(bio)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                        
                        // Binders Section (only show if friends)
                        if areFriends {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("\(displayName)'s Binders")
                                        .font(.title2.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                if isLoadingBinders {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                    .padding()
                                } else if userBinders.isEmpty {
                                    Text("No binders yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 12) {
                                        ForEach(userBinders, id: \.id) { binder in
                                            FriendBinderCard(binder: binder, friendService: friendService)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("Binders are private")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Become friends to view \(displayName)'s collection")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                        
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
            await loadUserData()
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
    
    private func loadUserData() async {
        do {
            // Check if users are friends
            let friendsStatus = try await friendService.areFriends(userId1: currentUserId, userId2: user.id)
            
            await MainActor.run {
                self.areFriends = friendsStatus
            }
            
            // Load binders if friends
            if friendsStatus {
                await MainActor.run {
                    self.isLoadingBinders = true
                }
                
                let binders = try await friendService.getFriendBinders(friendId: user.id)
                
                await MainActor.run {
                    self.userBinders = binders
                    self.isLoadingBinders = false
                }
            }
        } catch {
            await MainActor.run {
                self.isLoadingBinders = false
            }
            debugPrint("Error loading user data: \(error)")
        }
    }
}

// MARK: - Friend Binder Card

struct FriendBinderCard: View {
    let binder: UserBinder
    let friendService: FriendService
    @State private var showingBinderView = false
    
    var body: some View {
        Button {
            showingBinderView = true
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(binder.color)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "folder.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    )
                
                Text(binder.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if let game = binder.game {
                    Text(TCGType(rawValue: game)?.displayName ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .sheet(isPresented: $showingBinderView) {
            FriendBinderDetailView(binder: binder, friendService: friendService)
        }
    }
}

// MARK: - Friend Binder Detail View (simplified binder view for friends)

struct FriendBinderDetailView: View {
    let binder: UserBinder
    let friendService: FriendService
    @State private var binderCards: [UserBinderCard] = []
    @State private var fullCards: [TCGCard] = []
    @State private var isLoading = true
    @State private var isLoadingDetails = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedBackground") private var selectedBackground: BackgroundType = .potential
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground(selectedBackground: selectedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading cards...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(Array(fullCards.enumerated()), id: \.offset) { index, card in
                                FriendCardSlot(
                                    card: card, 
                                    binderCard: binderCards.first { $0.cardId == card.id },
                                    friendService: friendService
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(binder.name)
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
            await loadBinderCards()
        }
    }
    
    private func loadBinderCards() async {
        print("🔍 [DEBUG] Starting to load friend binder cards")
        print("🔍 [DEBUG] Binder ID: \(binder.id ?? "nil")")
        print("🔍 [DEBUG] Binder Name: \(binder.name)")
        print("🔍 [DEBUG] Binder Game: \(binder.game ?? "nil")")
        
        do {
            let cards = try await friendService.getFriendBinderCards(binderId: binder.id!)
            
            print("🔍 [DEBUG] Retrieved \(cards.count) cards from database")
            for (index, card) in cards.enumerated() {
                print("🔍 [DEBUG] Card \(index): ID='\(card.cardId)', Qty=\(card.qty), Notes='\(card.notes ?? "nil")', Condition='\(card.condition ?? "nil")'")
            }
            
            await MainActor.run {
                self.binderCards = cards
                self.isLoading = false
                self.isLoadingDetails = true
            }
            
            // Load full card details using batch approach (same as personal binders)
            print("🔍 [DEBUG] Starting to load full card details using batch approach...")
            var loadedFullCards: [TCGCard] = []
            
            // Determine the card type from the binder
            let cardType: TCGType
            if let game = binder.game?.lowercased() {
                switch game {
                case "pokemon", "pkm":
                    cardType = .pokemon
                case "yugioh", "ygo":
                    cardType = .yugioh
                case "one_piece", "op":
                    cardType = .onePiece
                default:
                    cardType = .onePiece // Default fallback
                }
            } else {
                cardType = .onePiece // Default fallback
            }
            
            print("🔍 [DEBUG] Determined card type: \(cardType.rawValue)")
            
            do {
                loadedFullCards = try await friendService.getCardDetails(for: cards, cardType: cardType)
                print("🔍 [DEBUG] Successfully loaded \(loadedFullCards.count) cards using batch approach")
            } catch {
                print("❌ [DEBUG] Error loading card details with batch approach: \(error)")
                // Create fallback cards for all
                loadedFullCards = cards.map { binderCard in
                    TCGCard(
                        id: binderCard.cardId,
                        name: "Unknown Card",
                        imageURL: URL(string: "about:blank")!,
                        setID: "unknown",
                        rarity: nil
                    )
                }
            }
            
            print("🔍 [DEBUG] Finished loading card details. Total cards: \(loadedFullCards.count)")
            
            await MainActor.run {
                self.fullCards = loadedFullCards
                self.isLoadingDetails = false
                print("🔍 [DEBUG] Updated UI with \(loadedFullCards.count) full cards")
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.isLoadingDetails = false
            }
            print("❌ [DEBUG] Error loading friend binder cards: \(error)")
        }
    }
}

// MARK: - Friend Card Slot Component

struct FriendCardSlot: View {
    let card: TCGCard
    let binderCard: UserBinderCard?
    let friendService: FriendService
    @State private var showingCardDetail = false
    
    var body: some View {
        Button {
            print("👆 [DEBUG] Tapped on card: '\(card.id)' with imageURL: '\(card.imageURL.absoluteString)'")
            showingCardDetail = true
        } label: {
            ZStack {
                CardImageView(imageUrl: card.imageURL.absoluteString)
                    .aspectRatio(0.7, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onAppear {
                        print("🖼️ [DEBUG] CardImageView appeared for card: '\(card.id)' with URL: '\(card.imageURL.absoluteString)'")
                    }
                
                // Quantity indicator if more than 1
                if let binderCard = binderCard, binderCard.qty > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(binderCard.qty)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .clipShape(Capsule())
                                .padding(4)
                        }
                        Spacer()
                    }
                }
                
                // Notes indicator
                if let binderCard = binderCard, let notes = binderCard.notes, !notes.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "note.text")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .padding(4)
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingCardDetail) {
            if let binderCard = binderCard {
                FriendCardDetailView(
                    card: card, 
                    binderCard: binderCard,
                    friendService: friendService
                )
            }
        }
    }
}

// MARK: - Friend Card Detail View

struct FriendCardDetailView: View {
    let card: TCGCard
    let binderCard: UserBinderCard
    let friendService: FriendService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedBackground") private var selectedBackground: BackgroundType = .potential
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground(selectedBackground: selectedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Card Image
                        HStack {
                            Spacer()
                            CardImageView(imageUrl: card.imageURL.absoluteString, width: 200, height: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Spacer()
                        }
                        
                        // Card Info
                        VStack(alignment: .leading, spacing: 16) {
                            // Card Name and Basic Info
                            VStack(alignment: .leading, spacing: 8) {
                                Text(card.name)
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("Set: \(card.setID)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if let rarity = card.rarity {
                                        Text("Rarity: \(rarity)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            
                            // Collection Info
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "number")
                                        .foregroundColor(.blue)
                                    Text("Quantity")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(binderCard.qty)")
                                        .font(.headline.weight(.bold))
                                        .foregroundColor(.blue)
                                }
                                
                                if let condition = binderCard.condition, !condition.isEmpty {
                                    HStack {
                                        Image(systemName: "star")
                                            .foregroundColor(.orange)
                                        Text("Condition")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(condition)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                if let addedAt = binderCard.addedAt {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.green)
                                        Text("Added")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(formatDate(addedAt))
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            
                            // Notes Section (Read-only for friends)
                            if let notes = binderCard.notes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "note.text")
                                            .foregroundColor(.purple)
                                        Text("Owner's Notes")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    
                                    Text(notes)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}