import SwiftUI

struct ContentView: View {
    @StateObject private var vm = BinderViewModel()

    var body: some View {
        ZStack {
            PastelPaperBackground()
                .ignoresSafeArea()
            VStack(spacing: 10) {
                header
                searchBar
                if let set = currentSet {
                    BinderSpreadPager(set: set)
                        .environmentObject(vm)
                        .padding(.horizontal, 8)
                } else {
                    Text("No set selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.top, 8)
        }
    }

    private var currentSet: TCGSet? {
        vm.sets.first(where: { $0.id == vm.currentSetID })
    }

    private var header: some View {
        HStack(spacing: 12) {
            Picker("Set", selection: Binding(
                get: { vm.currentSetID ?? vm.sets.first?.id ?? "" },
                set: { vm.currentSetID = $0 }
            )) {
                ForEach(vm.sets) { set in
                    Text(set.name).tag(set.id)
                }
            }
            .pickerStyle(.segmented)

            if let set = currentSet {
                Text("\(vm.currentSpreadIndex(for: set.id) + 1) / \(max(1, vm.spreads(for: set).count))")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(.horizontal)
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

// MARK: - Pager of spreads

struct BinderSpreadPager: View {
    let set: TCGSet
    @EnvironmentObject var vm: BinderViewModel

    var spreads: [[TCGCard]] { vm.spreads(for: set) }

    var body: some View {
        TabView(selection: Binding(
            get: { vm.currentSpreadIndex(for: set.id) },
            set: { vm.setSpreadIndex($0, for: set.id) }
        )) {
            ForEach(Array(spreads.enumerated()), id: \.offset) { idx, spread in
                BinderSpreadView(leftRightCards: spread)
                    .tag(idx)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.22), value: vm.currentSpreadIndex(for: set.id))
    }
}

// MARK: - Two-page spread (3x3 each page)

struct BinderSpreadView: View {
    let leftRightCards: [TCGCard]

    private var leftPage: ArraySlice<TCGCard> { leftRightCards.prefix(9) }
    private var rightPage: ArraySlice<TCGCard> { leftRightCards.dropFirst(9).prefix(9) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("BinderGreen").opacity(0.35))
                    .overlay(HandDrawnEdge(cornerRadius: 16).stroke(Color.black.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)

                HStack(spacing: 0) {
                    BinderPageGrid(cards: Array(leftPage))
                        .frame(width: geo.size.width * 0.48)
                        .padding(.leading, 10)
                    Spine()
                        .frame(width: geo.size.width * 0.04)
                    BinderPageGrid(cards: Array(rightPage))
                        .frame(width: geo.size.width * 0.48)
                        .padding(.trailing, 10)
                }
                .padding(.vertical, 8)
            }
        }
        .frame(height: 520)
    }
}

// MARK: - Single page grid

struct BinderPageGrid: View {
    @EnvironmentObject var vm: BinderViewModel
    let cards: [TCGCard]

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .center), count: 3)

    var body: some View {
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(cards) { card in
                CardSlot(card: card)
            }
            if cards.count < 9 {
                ForEach(0..<(9 - cards.count), id: \.self) { _ in
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
        ZStack(alignment: .topTrailing) {
            RemoteImage(url: card.imageURL)
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

            Button {
                vm.toggleFavorite(card)
            } label: {
                Image(systemName: vm.favorites.contains(card.id) ? "star.fill" : "star")
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(6)
        }
        .frame(minHeight: 120, maxHeight: 180)
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
            .frame(minHeight: 120, maxHeight: 180)
    }
}

// MARK: - Card detail modal

struct CardDetailView: View {
    @EnvironmentObject var vm: BinderViewModel
    let card: TCGCard

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                RemoteImage(url: card.imageURL)
                    .frame(height: 320)

                VStack(spacing: 6) {
                    Text(card.name)
                        .font(.title3).bold()
                    Text(card.setID)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let r = card.rarity {
                        Text("Rarity: \(r)")
                            .font(.footnote)
                            .padding(.top, 2)
                    }
                }

                Spacer()
            }
            .padding()
            .background(PastelPaperBackground().ignoresSafeArea())
            .navigationTitle("Card")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        vm.toggleFavorite(card)
                    } label: {
                        Image(systemName: vm.favorites.contains(card.id) ? "star.fill" : "star")
                    }
                }
            }
        }
    }
}

// MARK: - Binder spine & hand-drawn flourishes

struct Spine: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.12), .clear, Color.black.opacity(0.12)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            VStack(spacing: 6) {
                Capsule().fill(Color.black.opacity(0.18)).frame(width: 28, height: 6)
                Capsule().fill(Color.black.opacity(0.18)).frame(width: 28, height: 6)
                Capsule().fill(Color.black.opacity(0.18)).frame(width: 28, height: 6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}

struct HandDrawnEdge: Shape {
    let cornerRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: cornerRadius)
        p = p.strokedPath(.init(lineWidth: 1, lineCap: .round, lineJoin: .round, miterLimit: 2, dash: [3,4,2,5], dashPhase: 2))
        return p
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