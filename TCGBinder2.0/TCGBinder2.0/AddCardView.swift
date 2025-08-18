import SwiftUI

struct AddCardView: View {
    @EnvironmentObject var vm: BinderViewModel
    @Binding var isPresented: Bool
    @StateObject private var onePieceAPIService = OnePieceAPIService()
    @StateObject private var pokemonAPIService = PokemonAPIService()
    let selectedBackground: BackgroundType
    
    private var currentAPIService: any TCGAPIService {
        switch vm.selectedTCG {
        case .onePiece:
            return onePieceAPIService
        case .pokemon:
            return pokemonAPIService
        }
    }
    
    @State private var searchText = ""
    @State private var selectedSetId: String?
    @State private var selectedCard: OnePieceCard?
    @State private var showingSetPicker = false
    @State private var showingCardDetail = false
    
    var currentSet: TCGSet? {
        vm.sets.first(where: { $0.id == vm.currentSetID })
    }
    
    var availableSets: [(id: String, name: String)] {
        currentAPIService.getAvailableSets()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground(selectedBackground: selectedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Header
                    headerView
                    
                    // Search Section
                    searchSection
                    
                    // Results
                    if searchText.isEmpty {
                        emptySearchState
                    } else if currentAPIService.isLoading {
                        loadingView
                    } else if currentAPIService.searchResults.isEmpty {
                        emptyStateView
                    } else if let errorMessage = currentAPIService.errorMessage {
                        errorView(errorMessage)
                    } else {
                        cardResultsList
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Add \(vm.selectedTCG.displayName) Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
            }
        }
        .onAppear {
            // Sets will be loaded dynamically during search
        }
        .sheet(isPresented: $showingCardDetail) {
            if let card = selectedCard {
                CardDetailSheet(
                    card: card, 
                    isPresented: $showingCardDetail,
                    onAddToBinder: {
                        addSelectedCard()
                        showingCardDetail = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingSetPicker) {
            setPickerSheet
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("Search \(vm.selectedTCG.displayName) TCG Cards")
                .font(.title3.bold())
            
            if let set = currentSet {
                Text("Adding to \(set.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 12) {
            // Set Selection (Optional)
            Button {
                // Load sets only when picker is opened
                Task {
                    await currentAPIService.loadAllSets()
                }
                showingSetPicker = true
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                    if let setId = selectedSetId,
                       let setName = availableSets.first(where: { $0.id == setId })?.name {
                        Text(setName)
                            .foregroundStyle(.primary)
                    } else {
                        Text("All Sets (Optional Filter)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            .foregroundStyle(.primary)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search \(vm.selectedTCG.displayName) cards", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        clearSearchResults()
                        selectedCard = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .onChange(of: searchText) { _, newValue in
                if newValue.count >= 3 {
                    // Auto-search when user types 3+ characters (debounced)
                    performSearch(query: newValue)
                } else if newValue.isEmpty {
                    clearSearchResults()
                    selectedCard = nil
                }
            }
        }
    }
    
    // MARK: - Empty Search State
    private var emptySearchState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("Search \(vm.selectedTCG.displayName) Cards")
                    .font(.headline)
                
                Text("Type a card name to search the \(vm.selectedTCG.displayName) TCG database")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(vm.selectedTCG == .onePiece ? "Examples: Luffy, Zoro, Ace, Whitebeard" : "Examples: Pikachu, Charizard, Blastoise")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Results List
    private var cardResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(currentAPIService.searchResults) { card in
                    DetailedOnePieceCardRow(
                        card: card,
                        isSelected: selectedCard?.id == card.id
                    ) {
                        // Main tap shows detail sheet
                        selectedCard = card
                        showingCardDetail = true
                    } onDetailTap: {
                        // Detail tap also shows detail sheet
                        selectedCard = card
                        showingCardDetail = true
                    }
                }
                
                // Load More Button
                if currentAPIService.canLoadMore {
                    Button {
                        currentAPIService.loadMoreResults()
                    } label: {
                        HStack {
                            if currentAPIService.isLoadingMore {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading More...")
                            } else {
                                Image(systemName: "arrow.down.circle")
                                Text("Load More Results")
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(currentAPIService.isLoadingMore)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Searching \(vm.selectedTCG.displayName) cards...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No cards found")
                .font(.headline)
            
            Text("Try searching for different card names or select a different set")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Pokemon Placeholder View
    private var pokemonPlaceholderView: some View {
        VStack(spacing: 16) {
            Image("pokemon")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            
            Text("Pokémon TCG Coming Soon!")
                .font(.headline)
            
            Text("Pokémon card search will be available in a future update. For now, enjoy building your One Piece collection!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                performSearch()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Set Picker Sheet
    private var setPickerSheet: some View {
        NavigationView {
            List {
                // Clear selection option
                Button {
                    selectedSetId = nil
                    showingSetPicker = false
                } label: {
                    HStack {
                        Text("All Sets")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedSetId == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                // Available sets
                ForEach(availableSets, id: \.id) { set in
                    Button {
                        selectedSetId = set.id
                        showingSetPicker = false
                        // Re-search if there's text
                        if !searchText.isEmpty {
                            performSearch()
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(set.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                Text("Set: \(set.id)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedSetId == set.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingSetPicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Functions
    private func performSearch() {
        performSearch(query: searchText)
    }
    
    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            print("⚠️ Search canceled - empty query")
            return 
        }
        
        print("🚀 Starting search from AddCardView")
        print("📝 Query: '\(query)'")
        print("📦 Selected Set: \(selectedSetId ?? "all sets")")
        print("🎮 TCG Type: \(vm.selectedTCG.displayName)")
        
        // Use the appropriate API service based on TCG type
        currentAPIService.searchCards(query: query, setId: selectedSetId)
    }
    
    private func clearSearchResults() {
        onePieceAPIService.searchResults = []
        pokemonAPIService.searchResults = []
    }
    
    private func addSelectedCard() {
        guard let card = selectedCard,
              let setID = vm.currentSetID else { return }
        
        vm.addOnePieceCard(card, to: setID)
        isPresented = false
    }
}

// MARK: - Detailed One Piece Card Row
struct DetailedOnePieceCardRow: View {
    let card: OnePieceCard
    let isSelected: Bool
    let onTap: () -> Void
    let onDetailTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Card Image
            AsyncImage(url: URL(string: card.image ?? "")) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.06))
            }
            .frame(width: 80, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                onDetailTap()
            }
            
            // Card Details
            VStack(alignment: .leading, spacing: 6) {
                // Name and Set
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    if let setId = card.setId {
                        Text("Set: \(setId)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Stats Row 1
                HStack(spacing: 16) {
                    if let cost = card.cost {
                        StatBadge(icon: "circle.fill", label: "Cost", value: cost, color: .blue)
                    }
                    
                    if let power = card.power {
                        StatBadge(icon: "bolt.fill", label: "Power", value: power, color: .orange)
                    }
                }
                
                // Stats Row 2
                HStack(spacing: 16) {
                    if let counter = card.counter {
                        StatBadge(icon: "shield.fill", label: "Counter", value: counter, color: .green)
                    }
                    
                    if let rarity = card.rarity {
                        StatBadge(icon: "star.fill", label: "Rarity", value: rarity, color: .yellow)
                    }
                }
                
                // Price Row (if available)
                if let marketPrice = card.marketPrice, marketPrice > 0 {
                    HStack(spacing: 16) {
                        StatBadge(icon: "dollarsign.circle.fill", label: "Market", value: String(format: "$%.2f", marketPrice), color: .mint)
                        
                        if let inventoryPrice = card.inventoryPrice, inventoryPrice > 0 {
                            StatBadge(icon: "tag.fill", label: "Inventory", value: String(format: "$%.2f", inventoryPrice), color: .teal)
                        }
                    }
                }
                
                // Additional Info
                HStack(spacing: 8) {
                    if let color = card.color {
                        Text(color)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                    
                    if let type = card.type {
                        Text(type)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.1))
                            .foregroundStyle(.indigo)
                            .clipShape(Capsule())
                    }
                }
                
                // Sub Types
                if let subTypes = card.subTypes, !subTypes.isEmpty {
                    Text(subTypes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                
                // Effect Preview (first line)
                if let effect = card.effect, !effect.isEmpty {
                    Text(effect)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Tap indicator
            VStack {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Stat Badge Component
struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Card Detail Sheet
struct CardDetailSheet: View {
    let card: OnePieceCard
    @Binding var isPresented: Bool
    let onAddToBinder: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Card Image
                    HStack {
                        Spacer()
                        AsyncImage(url: URL(string: card.image ?? "")) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.06))
                        }
                        .frame(width: 200, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 10)
                        Spacer()
                    }
                    
                    // Card Name and Set
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let setId = card.setId {
                            Text("Set: \(setId)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let number = card.number {
                            Text("Card Number: \(number)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Stats Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        if let cost = card.cost {
                            DetailStatCard(title: "Cost", value: cost, icon: "circle.fill", color: .blue)
                        }
                        
                        if let power = card.power {
                            DetailStatCard(title: "Power", value: power, icon: "bolt.fill", color: .orange)
                        }
                        
                        if let counter = card.counter {
                            DetailStatCard(title: "Counter", value: counter, icon: "shield.fill", color: .green)
                        }
                        
                        if let rarity = card.rarity {
                            DetailStatCard(title: "Rarity", value: rarity, icon: "star.fill", color: .yellow)
                        }
                        
                        if let color = card.color {
                            DetailStatCard(title: "Color", value: color, icon: "paintbrush.fill", color: .purple)
                        }
                        
                        if let type = card.type {
                            DetailStatCard(title: "Type", value: type, icon: "tag.fill", color: .indigo)
                        }
                        
                        if let attribute = card.attribute {
                            DetailStatCard(title: "Attribute", value: attribute, icon: "sparkles", color: .pink)
                        }
                        
                        if let marketPrice = card.marketPrice, marketPrice > 0 {
                            DetailStatCard(title: "Market Price", value: String(format: "$%.2f", marketPrice), icon: "dollarsign.circle.fill", color: .mint)
                        }
                        
                        if let inventoryPrice = card.inventoryPrice, inventoryPrice > 0 {
                            DetailStatCard(title: "Inventory Price", value: String(format: "$%.2f", inventoryPrice), icon: "tag.fill", color: .teal)
                        }
                        
                        if let life = card.life, life != "NULL", !life.isEmpty {
                            DetailStatCard(title: "Life", value: life, icon: "heart.fill", color: .red)
                        }
                    }
                    
                    // Sub Types
                    if let subTypes = card.subTypes, !subTypes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sub Types")
                                .font(.headline)
                            
                            Text(subTypes)
                                .font(.body)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Effect
                    if let effect = card.effect, !effect.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Effect")
                                .font(.headline)
                            
                            Text(effect)
                                .font(.body)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Trigger
                    if let trigger = card.trigger, !trigger.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trigger")
                                .font(.headline)
                            
                            Text(trigger)
                                .font(.body)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Add to Binder Button
                    Button {
                        onAddToBinder()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add to Binder")
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle("Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Detail Stat Card
struct DetailStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}


#Preview {
    AddCardView(isPresented: .constant(true), selectedBackground: .original)
        .environmentObject(BinderViewModel())
}