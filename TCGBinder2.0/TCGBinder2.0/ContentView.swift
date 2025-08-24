import SwiftUI

// MARK: - Card Image Component
struct CardImageView: View {
    let imageUrl: String
    let width: CGFloat?
    let height: CGFloat?
    
    init(imageUrl: String, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.imageUrl = imageUrl
        self.width = width
        self.height = height
    }
    
    var body: some View {
        AsyncImage(url: URL(string: imageUrl)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .if(width != nil && height != nil) { view in
                        view.frame(width: width!, height: height!)
                    }
            case .failure(let error):
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                            Text("Failed")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
                    .if(width != nil && height != nil) { view in
                        view.frame(width: width!, height: height!)
                    }
                    .aspectRatio(5.0/7.0, contentMode: .fit)
            case .empty:
                ProgressView()
                    .if(width != nil && height != nil) { view in
                        view.frame(width: width!, height: height!)
                    }
                    .aspectRatio(5.0/7.0, contentMode: .fit)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            @unknown default:
                EmptyView()
            }
        }
        .aspectRatio(5.0/7.0, contentMode: .fit)
        .cornerRadius(8)
    }
}

struct ContentView: View {
    @StateObject private var vm = BinderViewModel()
    @StateObject private var navigationState = NavigationStateManager()
    @State private var selectedTab = 0
    @State private var showingAddBinder = false
    @State private var showBinder = false
    @AppStorage("selectedBackground") private var selectedBackground: BackgroundType = .potential
    @AppStorage("appColorScheme") private var selectedColorScheme: AppColorScheme = .system
    @Namespace private var binderTransition
    
    var body: some View {
        // Main TabView with navbar
        TabView(selection: $selectedTab) {
            // Home Tab - Landing/Binder View
            NavigationStack {
                if showBinder {
                    BinderMainView(
                        showBinder: $showBinder, 
                        selectedBackground: $selectedBackground,
                        selectedColorScheme: $selectedColorScheme,
                        binderTransition: binderTransition
                    )
                    .environmentObject(vm)
                    .navigationTransition(.zoom(sourceID: "selectedBinder", in: binderTransition))
                } else {
                    LandingView(
                        showBinder: $showBinder,
                        selectedBackground: $selectedBackground,
                        selectedColorScheme: $selectedColorScheme,
                        binderTransition: binderTransition
                    )
                    .environmentObject(vm)
                    .navigationTransition(.zoom(sourceID: "selectedBinder", in: binderTransition))
                }
            }
            .tabItem {
                Image(systemName: "house")
                Text("Home")
            }
            .tag(0)
            .onChange(of: selectedTab) { oldValue, newValue in
                // When home tab is tapped, always go back to landing page
                if newValue == 0 && showBinder {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showBinder = false
                    }
                }
                // When add tab is tapped, show add binder
                if newValue == 2 {
                    showingAddBinder = true
                    selectedTab = 0 // Reset to home tab
                }
            }
            
            // Friends Tab
            NavigationStack {
                FriendsView()
            }
            .tabItem {
                Image(systemName: "person.2")
                Text("Friends")
            }
            .badge(2) // Example badge for friend requests
            .tag(1)
            
            
            // Hidden Add Tab (handled by tab bar button)
            Color.clear
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("Add")
                }
                .tag(2)
            
            // Profile Tab
            NavigationStack {
                MainProfileView()
                    .environmentObject(vm)
            }
            .tabItem {
                Image(systemName: "person.crop.circle")
                Text("Profile")
            }
            .tag(3)
            
            // Settings Tab
            NavigationStack {
                EnhancedSettingsView()
                    .environmentObject(vm)
            }
            .tabItem {
                Image(systemName: "gearshape")
                Text("Settings")
            }
            .tag(4)
        }
        .opacity(navigationState.shouldShowTabBar ? 1 : 0)
        .onAppear {
            setupTabBarAppearance()
        }
        .environment(\.navigationState, navigationState)
        .environmentObject(vm)
        .sheet(isPresented: $showingAddBinder) {
            AddBinderView()
                .environmentObject(vm)
        }
        .preferredColorScheme(selectedColorScheme.colorScheme)
        .animation(.easeInOut(duration: 0.6), value: showBinder)
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        
        // Configure blur effect
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        
        // Configure selected state
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
        
        // Configure normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

struct BinderMainView: View {
    @EnvironmentObject var vm: BinderViewModel
    @State private var showAddCard = false
    @State private var showNameEditor = false
    @State private var showDeleteConfirmation = false
    @State private var tempBinderName = ""
    @Binding var showBinder: Bool
    @Binding var selectedBackground: BackgroundType
    @Binding var selectedColorScheme: AppColorScheme
    let binderTransition: Namespace.ID

    var body: some View {
        ZStack {
            // Dynamic background based on selected binder color - zoom destination
            BinderDynamicBackground(binderColor: vm.selectedBinder.color)
            
            // Content layer - uses standard SwiftUI layout
            VStack(spacing: 8) {
                binderNameHeader
                searchBar
                
                if let set = currentSet {
                    BinderPageView(set: set)
                        .environmentObject(vm)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                    VStack {
                        Text("No set selected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Available sets: \(vm.sets.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
            
            // Floating Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showAddCard = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color("BinderGreen"))
                                .frame(width: 56, height: 56)
                                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                            
                            Image(systemName: "plus")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                        }
                    }
                    .scaleEffect(showAddCard ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showAddCard)
                    .padding(.trailing, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            Task {
                await vm.loadCardsIfNeeded()
            }
        }
        .onChange(of: vm.selectedTCG) { oldValue, newValue in
            Task {
                await vm.loadCardsIfNeeded()
            }
        }
        .onChange(of: vm.selectedUserBinder) { oldValue, newValue in
            Task {
                await vm.loadCardsIfNeeded()
            }
        }
        .sheet(isPresented: $showAddCard) {
            AddCardView(isPresented: $showAddCard, selectedBackground: selectedBackground)
                .environmentObject(vm)
                .preferredColorScheme(selectedColorScheme.colorScheme)
        }
        .alert("Delete Binder", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await vm.deleteCurrentBinder()
                        showBinder = false // Go back to home after deletion
                    } catch {
                        print("❌ Failed to delete binder: \(error)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this binder? This will permanently delete the binder and all its cards.")
        }
        .alert("Edit Binder Name", isPresented: $showNameEditor) {
            TextField("Binder Name", text: $tempBinderName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                vm.updateBinderName(tempBinderName)
            }
        } message: {
            Text("Enter a new name for your binder")
        }
    }

    private var currentSet: TCGSet? {
        vm.sets.first(where: { $0.id == vm.currentSetID })
    }
    
    private var binderNameHeader: some View {
        HStack {
            Button {
                showBinder = false
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.medium))
                    Text("Back")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.blue)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(vm.binderName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("\(vm.selectedTCG.displayName) Collection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    tempBinderName = vm.binderName
                    showNameEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }


    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search cards or set…", text: $vm.query)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onSubmit { vm.runSearch() }
                if !vm.query.isEmpty {
                    Button {
                        vm.query = ""
                        vm.searchResults = []
                    } label: { Image(systemName: "xmark.circle.fill") }
                }
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            if !vm.searchResults.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.searchResults.prefix(20)) { card in
                            Button {
                                vm.jump(to: card)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(card.name)
                                        .lineLimit(1)
                                    Text(card.setID)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.7), in: Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Seamless Pagination Binder View

struct BinderPageView: View {
    let set: TCGSet
    @EnvironmentObject var vm: BinderViewModel
    @State private var scrollOffset: CGFloat = 0
    @State private var currentScrollIndex: Int = 0

    var pages: [[TCGCard]] { vm.pages(for: set) }
    var currentPageIndex: Int { vm.currentPageIndex(for: set.id) }

    var body: some View {
        GeometryReader { geometry in
            let pageWidth = min(geometry.size.width - 20, 450)  // Reduced margins, increased max width
            // Use almost all available height - minimal reserve for indicators
            let availableHeight = geometry.size.height - 20  // Minimal space for dots
            let pageHeight = availableHeight * 0.9  // Use 90% of available height
            
            VStack(spacing: 0) {
                // Simple ScrollView with TabView for page-by-page scrolling
                TabView(selection: $currentScrollIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, pageCards in
                        BinderSinglePage(cards: pageCards)
                            .frame(width: pageWidth, height: pageHeight)
                            .tag(pageIndex)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: currentScrollIndex) { oldValue, newValue in
                    vm.setPageIndex(newValue, for: set.id)
                }
                
                // Small page indicator circles at bottom
                if pages.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(currentScrollIndex == index ? Color.cyan : Color.white.opacity(0.4))
                                .frame(width: 4, height: 4)
                                .shadow(color: currentScrollIndex == index ? .cyan : .clear, radius: 2)
                                .scaleEffect(currentScrollIndex == index ? 1.3 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentScrollIndex)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .onAppear {
                // Initialize to current page index
                currentScrollIndex = currentPageIndex
            }
            .onChange(of: currentPageIndex) { oldValue, newValue in
                // When page changes programmatically, update TabView
                if newValue != currentScrollIndex {
                    currentScrollIndex = newValue
                }
            }
        }
    }
}

// MARK: - Single Page Layout

struct BinderSinglePage: View {
    let cards: [TCGCard]
    @State private var glowIntensity: Double = 0.6
    
    var body: some View {
        ZStack {
            // Futuristic background with gradient and glow effects
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.9),
                            Color("BinderGreen").opacity(0.2),
                            Color.black.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.cyan.opacity(glowIntensity * 0.3),
                                    Color.purple.opacity(glowIntensity * 0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 200
                            )
                        )
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glowIntensity)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.6),
                                    Color.purple.opacity(0.4),
                                    Color.cyan.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .cyan.opacity(0.3), radius: 20, x: 0, y: 0)
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
            
            VStack(spacing: 20) {
                Spacer(minLength: 20)
                
                // Enhanced card grid (no entrance animation)
                BinderPageGrid(cards: cards)
                    .padding(.horizontal, 24)
                
                Spacer(minLength: 16)
            }
        }
        .onAppear {
            // Start glow animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }
        }
    }
}

// MARK: - Single page grid

struct BinderPageGrid: View {
    @EnvironmentObject var vm: BinderViewModel
    let cards: [TCGCard]

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .leading), count: 3)

    var body: some View {
        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            ForEach(0..<9, id: \.self) { index in
                if index < cards.count {
                    CardSlot(card: cards[index])
                } else {
                    EmptyCardSlot()
                }
            }
        }
    }
}

struct CardSlot: View {
    @EnvironmentObject var vm: BinderViewModel
    let card: TCGCard
    @State private var showDetail = false
    @State private var pressed = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack {
            // Enhanced card display without shimmer
            CardImageView(imageUrl: card.imageURL.absoluteString)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: pressed ? [Color.cyan, Color.purple] : [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: pressed ? 2 : 1
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: pressed)
                )
                .shadow(color: pressed ? .cyan.opacity(0.6) : .black.opacity(0.2), radius: pressed ? 12 : 4, x: 0, y: pressed ? 6 : 2)
            
            // Rarity indicator glow
            if let rarity = card.rarity, !rarity.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(rarityColor(rarity), lineWidth: pressed ? 3 : 2)
                    .opacity(pressed ? 0.8 : 0.5)
                    .shadow(color: rarityColor(rarity), radius: pressed ? 8 : 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: pressed)
            }
        }
        .scaleEffect(pressed ? 0.95 : 1.0)
        .rotation3DEffect(
            .degrees(pressed ? 5 : 0),
            axis: (x: 1, y: 1, z: 0),
            perspective: 0.8
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pressed)
            .onLongPressGesture(minimumDuration: 0.15, pressing: { p in
                pressed = p
            }, perform: {
                showDetail = true
            })
            .onTapGesture {
                showDetail = true
            }
            .contextMenu {
                // Only show context menu if we're in a binder view
                if vm.selectedUserBinder != nil {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Remove from Binder", systemImage: "trash")
                    }
                }
            }
            .sheet(isPresented: $showDetail) {
                CardDetailView(card: card)
                    .environmentObject(vm)
            }
            .alert("Remove Card", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    vm.removeCardFromCurrentBinder(card)
                }
            } message: {
                Text("Are you sure you want to remove \"\(card.name)\" from this binder?")
            }
    }
    
    // Rarity color mapping
    private func rarityColor(_ rarity: String) -> Color {
        switch rarity.lowercased() {
        case "common", "c": return .gray
        case "uncommon", "u": return .green  
        case "rare", "r": return .blue
        case "super rare", "sr": return .purple
        case "secret rare", "sec": return .red
        case "leader", "l": return .orange
        case "legendary", "legend": return .yellow
        default: return .white
        }
    }
}

struct EmptyCardSlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.gray.opacity(0.1),
                        Color.black.opacity(0.05)
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 60
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.cyan.opacity(0.2),
                                Color.white.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .overlay(
                // Plus icon for adding cards
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.4))
            )
            .aspectRatio(5.0/7.0, contentMode: .fit)
    }
}

// MARK: - Card detail modal

struct CardDetailView: View {
    @EnvironmentObject var vm: BinderViewModel
    @Environment(\.dismiss) private var dismiss
    let card: TCGCard
    @State private var showDeleteConfirmation = false
    @State private var userNotes: String = ""
    @State private var isEditingNotes: Bool = false
    @State private var isSavingNotes: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Card Image
                    HStack {
                        Spacer()
                        CardImageView(imageUrl: card.imageURL.absoluteString, width: 200, height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Spacer()
                    }
                    
                    // Card Name and Set
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Set: \(card.setID)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Stats Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        if let cost = card.cost, cost != "NULL" {
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
                    
                    // Personal Notes Section - Only for binder cards
                    if vm.selectedUserBinder != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Personal Notes")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if !isEditingNotes {
                                    Button("Edit") {
                                        isEditingNotes = true
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                                }
                            }
                            
                            if isEditingNotes {
                                VStack(spacing: 12) {
                                    TextEditor(text: $userNotes)
                                        .frame(minHeight: 100)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    HStack(spacing: 12) {
                                        Button("Cancel") {
                                            // Reload original notes
                                            loadUserNotes()
                                            isEditingNotes = false
                                        }
                                        .foregroundStyle(.secondary)
                                        
                                        Spacer()
                                        
                                        Button("Save") {
                                            saveUserNotes()
                                        }
                                        .disabled(isSavingNotes)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(isSavingNotes ? Color.gray : Color.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            } else {
                                if userNotes.isEmpty {
                                    Text("Tap Edit to add your notes about this card...")
                                        .foregroundStyle(.secondary)
                                        .font(.body)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Text(userNotes)
                                        .font(.body)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    // Delete Button - Works for all TCG types when viewing binder cards
                    if vm.selectedUserBinder != nil {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove from Binder")
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 20)
                    }
                }
                .padding()
            }
            .navigationTitle("Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    DismissButton()
                }
            }
            .onAppear {
                // Load user notes when the view appears (only for binder cards)
                if vm.selectedUserBinder != nil {
                    loadUserNotes()
                }
            }
        }
        .alert("Remove Card", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                vm.removeCardFromCurrentBinder(card)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to remove \"\(card.name)\" from this binder?")
        }
    }
    
    // MARK: - Notes Helper Functions
    
    private func loadUserNotes() {
        guard let selectedBinder = vm.selectedUserBinder,
              let binderId = selectedBinder.id else {
            return
        }
        
        Task {
            do {
                let notes = try await vm.loadCardNotes(cardId: card.id, binderId: binderId)
                await MainActor.run {
                    userNotes = notes
                }
            } catch {
                print("❌ Failed to load card notes: \(error)")
            }
        }
    }
    
    private func saveUserNotes() {
        guard let selectedBinder = vm.selectedUserBinder,
              let binderId = selectedBinder.id else {
            return
        }
        
        isSavingNotes = true
        
        Task {
            do {
                try await vm.saveCardNotes(cardId: card.id, binderId: binderId, notes: userNotes)
                await MainActor.run {
                    isSavingNotes = false
                    isEditingNotes = false
                }
            } catch {
                await MainActor.run {
                    isSavingNotes = false
                }
                print("❌ Failed to save card notes: \(error)")
            }
        }
    }
}

// Helper view for dismiss button
struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Button("Done") {
            dismiss()
        }
    }
}


// MARK: - Hand-drawn flourishes

struct HandDrawnEdge: Shape {
    let cornerRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: cornerRadius)
        p = p.strokedPath(.init(lineWidth: 1, lineCap: .round, lineJoin: .round, miterLimit: 2, dash: [3,4,2,5], dashPhase: 2))
        return p
    }
}

struct BinderDynamicBackground: View {
    let binderColor: Color
    @State private var backgroundOpacity: Double = 1.0  // Start visible for seamless transition
    
    var body: some View {
        LinearGradient(
            colors: [
                binderColor.opacity(0.8),
                binderColor.opacity(0.5),
                binderColor.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .opacity(backgroundOpacity)
        .ignoresSafeArea(.all) // This ensures it extends to all edges including safe areas
    }
}

struct AppBackground: View {
    let selectedBackground: BackgroundType
    
    var body: some View {
        GeometryReader { geometry in
            switch selectedBackground {
            case .original:
                PastelPaperBackground()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            case .potential:
                Image("potential background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            case .background2:
                Image("bakcground2")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
        }
        .ignoresSafeArea()
    }
}

struct PastelPaperBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color("BinderGreen").opacity(0.55),
                Color("BinderGreen").opacity(0.35)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            ZStack {
                Canvas { ctx, size in
                    let count = Int((size.width * size.height) / 2500)
                    for _ in 0..<count {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let rect = CGRect(x: x, y: y, width: 1, height: 1)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.03)))
                    }
                }
                .opacity(0.35)
            }
        )
    }
}

// MARK: - Navbar Components

struct FloatingAddButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background with blur and gradient
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.4 : 0.2),
                        radius: isPressed ? 4 : 8,
                        x: 0,
                        y: isPressed ? 2 : 4
                    )
                
                // Plus icon with animation
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .rotationEffect(.degrees(isPressed ? 45 : 0))
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { 
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
        } onPressingChanged: { pressing in
            if !pressing {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FriendsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "person.2.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)
                
                Text("Friends")
                    .font(.largeTitle.weight(.bold))
                
                Text("Connect with other collectors")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Example badge functionality
                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundColor(.red)
                    Text("2 new friend requests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct MainProfileView: View {
    @EnvironmentObject var vm: BinderViewModel
    @AppStorage("selectedBackground") private var selectedBackground: BackgroundType = .potential
    @State private var showFullProfile = false
    @State private var userProfile: Profile?
    @State private var userEmail = ""
    @StateObject private var profileService = ProfileService()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                // Profile Picture
                VStack(spacing: 16) {
                    if let avatarUrl = userProfile?.avatarUrl, !avatarUrl.isEmpty {
                        AsyncImage(url: URL(string: avatarUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    ProgressView()
                                        .tint(.white)
                                )
                        }
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(spacing: 8) {
                        Text(displayName)
                            .font(.title.weight(.bold))
                        
                        if let bio = userProfile?.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Text(userEmail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Total Binders: \(vm.userBinders.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Current Binder Info
                if let selectedBinder = vm.selectedUserBinder {
                    VStack(spacing: 12) {
                        Text("Current Binder")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Circle()
                                .fill(selectedBinder.color)
                                .frame(width: 20, height: 20)
                            
                            Text(selectedBinder.name)
                                .font(.title3.weight(.medium))
                            
                            if let game = selectedBinder.game {
                                Text("(\(TCGType(rawValue: game)?.displayName ?? "Unknown"))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                
                // Mini Binders Collection
                if !vm.userBinders.isEmpty {
                    VStack(spacing: 12) {
                        HStack {
                            Text("My Binders")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(vm.userBinders.enumerated()), id: \.offset) { index, binder in
                                    MiniBinder(
                                        userBinder: binder,
                                        isSelected: vm.selectedUserBinder?.id == binder.id,
                                        animationDelay: Double(index) * 0.1
                                    )
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                
                // Stats
                HStack(spacing: 40) {
                    StatView(title: "Cards", value: "\(vm.sets.flatMap { $0.cards }.count)")
                    StatView(title: "Sets", value: "\(vm.sets.count)")
                    StatView(title: "Binders", value: "\(vm.userBinders.count)")
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                
                // Profile Actions
                Button("Manage Account") {
                    showFullProfile = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showFullProfile) {
            ProfileView(selectedBackground: selectedBackground)
        }
        .task {
            await loadUserProfile()
        }
    }
    
    private var displayName: String {
        if let profile = userProfile {
            if let fullName = profile.fullName, !fullName.isEmpty {
                return fullName
            } else if let username = profile.username, !username.isEmpty {
                return username
            }
        }
        return "TCG Collector"
    }
    
    private func loadUserProfile() async {
        do {
            let currentUser = try await supabase.auth.session.user
            
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
                self.userProfile = profile
            }
            
        } catch {
            debugPrint("Error loading profile in MainProfileView: \(error)")
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Mini Binder Component

struct MiniBinder: View {
    @EnvironmentObject var vm: BinderViewModel
    let userBinder: UserBinder
    let isSelected: Bool
    let animationDelay: Double
    @State private var isPressed = false
    @State private var hasAppeared = false
    
    private var binderColor: Color {
        return userBinder.color
    }
    
    private var binderImageName: String {
        let assignedValue = Int(userBinder.assigned_value)
        let imageIndex = (assignedValue - 1) % 3
        
        switch imageIndex {
        case 0: return "binder2"
        case 1: return "binder3" 
        case 2: return "binder2-black"
        default: return "binder2"
        }
    }
    
    private var tcgImageName: String {
        guard let game = userBinder.game else { return "tcg-binder-title" }
        
        switch game {
        case "pokemon": return "pokemon"
        case "yugioh": return "yugioh"
        case "one_piece": return "logo_op"
        default: return "tcg-binder-title"
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Binder shadow
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(isSelected ? 0.15 : 0.08))
                    .frame(width: 84, height: 105)
                    .offset(x: 2, y: 3)
                
                // Binder base
                RoundedRectangle(cornerRadius: 8)
                    .fill(binderColor)
                    .frame(width: 84, height: 105)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                
                // Binder image
                Image(binderImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 78, height: 99)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // TCG logo
                VStack {
                    HStack {
                        Spacer()
                        Image(tcgImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 13)
                            .if(binderImageName == "binder2-black") { view in
                                view
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(3)
                            }
                            .padding(.top, 6)
                            .padding(.trailing, 6)
                    }
                    Spacer()
                }
            }
            .scaleEffect(hasAppeared ? (isPressed ? 0.95 : (isSelected ? 1.05 : 1.0)) : 0.3)
            .opacity(hasAppeared ? 1.0 : 0.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: hasAppeared)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        hasAppeared = true
                    }
                }
            }
            
            // Binder name
            Text(userBinder.name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 84)
        }
        .onTapGesture {
            // Quick press animation
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            // Select this binder
            vm.selectUserBinder(userBinder)
            
            // Reset press animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
}

struct AddBinderView: View {
    @EnvironmentObject var vm: BinderViewModel
    @Environment(\.dismiss) var dismiss
    @State private var binderName = ""
    @State private var selectedColor = Color.black
    @State private var selectedTCG = TCGType.onePiece
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let binderColors: [(name: String, color: Color)] = [
        ("Black", Color.black),
        ("Blue", Color.blue),
        ("Red", Color.red),
        ("Green", Color.green),
        ("Purple", Color.purple),
        ("Orange", Color.orange)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Create New Binder")
                            .font(.largeTitle.weight(.bold))
                        
                        Text("Add a new binder to organize your collection")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 20) {
                        // Binder Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Binder Name")
                                .font(.headline)
                            
                            TextField("Enter binder name", text: $binderName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.body)
                        }
                        
                        // TCG Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose Trading Card Game")
                                .font(.headline)
                            
                            VStack(spacing: 12) {
                                ForEach(TCGType.allCases, id: \.self) { tcgType in
                                    Button {
                                        selectedTCG = tcgType
                                    } label: {
                                        HStack(spacing: 12) {
                                            // TCG Logo
                                            Image(tcgType.logoImageName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                            
                                            // TCG Name
                                            Text(tcgType.displayName)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(.primary)
                                            
                                            Spacer()
                                            
                                            // Selection indicator
                                            if selectedTCG == tcgType {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(.blue)
                                            } else {
                                                Image(systemName: "circle")
                                                    .font(.title3)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(.ultraThinMaterial)
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedTCG == tcgType ? .blue : .clear, lineWidth: 2)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // Color Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose Color")
                                .font(.headline)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                                ForEach(Array(binderColors.enumerated()), id: \.offset) { index, colorOption in
                                    Button {
                                        selectedColor = colorOption.color
                                    } label: {
                                        VStack(spacing: 8) {
                                            Circle()
                                                .fill(colorOption.color)
                                                .frame(width: 50, height: 50)
                                                .overlay(
                                                    Circle()
                                                        .stroke(selectedColor == colorOption.color ? Color.blue : Color.clear, lineWidth: 3)
                                                )
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                                )
                                            
                                            Text(colorOption.name)
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // Create Button
                        Button {
                            createBinder()
                        } label: {
                            HStack {
                                if isCreating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "plus")
                                }
                                Text(isCreating ? "Creating..." : "Create Binder")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(binderName.isEmpty ? Color.gray : Color.blue)
                            )
                        }
                        .disabled(binderName.isEmpty || isCreating)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("New Binder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createBinder() {
        guard !binderName.isEmpty else { return }
        
        isCreating = true
        
        Task {
            do {
                try await vm.createNewBinder(name: binderName, color: selectedColor, game: selectedTCG)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
