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
    @State private var showBinder = false
    @State private var selectedBackground: BackgroundType = .original
    @State private var selectedColorScheme: AppColorScheme = .system
    @Namespace private var binderTransition
    
    init() {
        // Load saved background preference
        let savedBackground = UserDefaults.standard.string(forKey: "selectedBackground") ?? "original"
        _selectedBackground = State(initialValue: BackgroundType(rawValue: savedBackground) ?? .original)
        
        // Load saved color scheme preference
        let savedColorScheme = UserDefaults.standard.string(forKey: "selectedColorScheme") ?? "system"
        _selectedColorScheme = State(initialValue: AppColorScheme(rawValue: savedColorScheme) ?? .system)
    }

    var body: some View {
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
                .onChange(of: selectedBackground) { _, newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "selectedBackground")
                }
                .onChange(of: selectedColorScheme) { _, newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "selectedColorScheme")
                }
            } else {
                LandingView(
                    showBinder: $showBinder, 
                    selectedBackground: $selectedBackground,
                    selectedColorScheme: $selectedColorScheme,
                    binderTransition: binderTransition
                )
                .environmentObject(vm)
                .navigationTransition(.zoom(sourceID: "selectedBinder", in: binderTransition))
                .onChange(of: selectedBackground) { _, newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "selectedBackground")
                }
                .onChange(of: selectedColorScheme) { _, newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "selectedColorScheme")
                }
            }
        }
        .preferredColorScheme(selectedColorScheme.colorScheme)
        .animation(.easeInOut(duration: 0.6), value: showBinder)
    }
}

struct BinderMainView: View {
    @EnvironmentObject var vm: BinderViewModel
    @State private var showAddCard = false
    @State private var showNameEditor = false
    @State private var showProfile = false
    @State private var tempBinderName = ""
    @Binding var showBinder: Bool
    @Binding var selectedBackground: BackgroundType
    @Binding var selectedColorScheme: AppColorScheme
    let binderTransition: Namespace.ID

    var body: some View {
        ZStack {
            // Dynamic background based on selected binder color - zoom destination
            BinderDynamicBackground(binderColor: vm.selectedBinder.color)
                .onAppear {
                    Task {
                        await vm.loadPokemonCardsIfNeeded()
                    }
                }
                .onChange(of: vm.selectedTCG) { oldValue, newValue in
                    Task {
                        await vm.loadPokemonCardsIfNeeded()
                    }
                }
            
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
        .sheet(isPresented: $showAddCard) {
            AddCardView(isPresented: $showAddCard, selectedBackground: selectedBackground)
                .environmentObject(vm)
                .preferredColorScheme(selectedColorScheme.colorScheme)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(selectedBackground: selectedBackground)
                .preferredColorScheme(selectedColorScheme.colorScheme)
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
                    showProfile = true
                } label: {
                    Image(systemName: "person.circle")
                        .font(.title3)
                        .foregroundStyle(.blue)
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

// MARK: - Single Page View with Flip Animation

struct BinderPageView: View {
    let set: TCGSet
    @EnvironmentObject var vm: BinderViewModel
    @State private var dragOffset: CGSize = .zero
    @State private var isFlipping = false

    var pages: [[TCGCard]] { vm.pages(for: set) }
    var currentPageIndex: Int { vm.currentPageIndex(for: set.id) }

    var body: some View {
        GeometryReader { geometry in
            let pageWidth = min(geometry.size.width - 40, 380)
            let pageHeight = min(geometry.size.height - 20, pageWidth * 1.25)
            
            ZStack {
                // Current page
                if currentPageIndex < pages.count {
                    BinderSinglePage(cards: pages[currentPageIndex])
                        .frame(width: pageWidth, height: pageHeight)
                        .rotation3DEffect(
                            .degrees(Double(dragOffset.width / 10)),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: dragOffset.width < 0 ? .leading : .trailing
                        )
                        .offset(x: isFlipping ? 0 : dragOffset.width / 2)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFlipping)
                }
                
                // Next page preview (when swiping left)
                if dragOffset.width < -50 && currentPageIndex + 1 < pages.count {
                    BinderSinglePage(cards: pages[currentPageIndex + 1])
                        .frame(width: pageWidth, height: pageHeight)
                        .rotation3DEffect(
                            .degrees(Double(-90 + (dragOffset.width + 50) / 10)),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading
                        )
                        .opacity(0.7)
                }
                
                // Previous page preview (when swiping right)
                if dragOffset.width > 50 && currentPageIndex > 0 {
                    BinderSinglePage(cards: pages[currentPageIndex - 1])
                        .frame(width: pageWidth, height: pageHeight)
                        .rotation3DEffect(
                            .degrees(Double(90 - (dragOffset.width - 50) / 10)),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .trailing
                        )
                        .opacity(0.7)
                }
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isFlipping {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        handlePageFlip(translation: value.translation.width)
                    }
            )
        }
    }
    
    private func handlePageFlip(translation: CGFloat) {
        isFlipping = true
        
        if translation < -100 && currentPageIndex + 1 < pages.count {
            // Flip to next page
            vm.setPageIndex(currentPageIndex + 1, for: set.id)
        } else if translation > 100 && currentPageIndex > 0 {
            // Flip to previous page
            vm.setPageIndex(currentPageIndex - 1, for: set.id)
        }
        
        // Reset drag offset with animation
        dragOffset = .zero
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isFlipping = false
        }
    }
}

// MARK: - Single Page Layout

struct BinderSinglePage: View {
    let cards: [TCGCard]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("BinderGreen").opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.1), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            VStack(spacing: 16) {
                // Binder holes at top
                HStack(spacing: 40) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 20)
                
                // Card grid
                BinderPageGrid(cards: cards)
                    .padding(.horizontal, 20)
                
                Spacer(minLength: 10)
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

    var body: some View {
        CardImageView(imageUrl: card.imageURL.absoluteString)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressed)
            .onLongPressGesture(minimumDuration: 0.15, pressing: { p in
                pressed = p
            }, perform: {
                showDetail = true
            })
            .onTapGesture {
                showDetail = true
            }
            .sheet(isPresented: $showDetail) {
                CardDetailView(card: card)
                    .environmentObject(vm)
            }
    }
}

struct EmptyCardSlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.35))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.08), lineWidth: 1))
            .aspectRatio(5.0/7.0, contentMode: .fit)
    }
}

// MARK: - Card detail modal

struct CardDetailView: View {
    @EnvironmentObject var vm: BinderViewModel
    @Environment(\.dismiss) private var dismiss
    let card: TCGCard

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
                    
                    // Delete Button (Only for Pokemon cards)
                    if vm.selectedTCG == .pokemon {
                        Button {
                            vm.removePokemonCard(card)
                            dismiss()
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
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    binderColor.opacity(0.8),
                    binderColor.opacity(0.5),
                    binderColor.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea()
            .opacity(backgroundOpacity)
        }
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

#Preview {
    ContentView()
}
