import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

enum BackgroundType: String, CaseIterable, Identifiable {
    case original = "original"
    case potential = "potential"
    case background2 = "background2"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .original: return "Original"
        case .potential: return "Potential"
        case .background2: return "Background 2"
        }
    }
}

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct LandingView: View {
    @Binding var showBinder: Bool
    @Binding var selectedBackground: BackgroundType
    @Binding var selectedColorScheme: AppColorScheme
    @EnvironmentObject var vm: BinderViewModel
    let binderTransition: Namespace.ID
    @State private var binderScale: CGFloat = 1.0
    @State private var titleOpacity: Double = 0.0
    @State private var subtitleOpacity: Double = 0.0
    @State private var showProfile: Bool = false
    @State private var showTCGSelection: Bool = false
    @State private var showSettings: Bool = false
    @State private var isTransitioning: Bool = false
    
    var body: some View {
        ZStack {
            AppBackground(selectedBackground: selectedBackground)
                .ignoresSafeArea()
            
            
            // Main centered content
            VStack(spacing: 16) {
                // App Title
                Image("tcg-binder-title")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 150)
                    .opacity(isTransitioning ? 0.0 : titleOpacity)
                    .animation(.easeOut(duration: 0.3), value: isTransitioning)
                    .onLongPressGesture(minimumDuration: 3.0) {
                        // Hidden developer feature: long press title to clear all data
                        vm.clearAllData()
                    }
                
                // Binder Carousel
                BinderCarouselView(
                    showBinder: $showBinder,
                    binderTransition: binderTransition,
                    isTransitioning: $isTransitioning,
                    onExpansionTrigger: { color in
                        triggerExpansionAnimation(color: color)
                    }
                )
                .scaleEffect(binderScale)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: binderScale)
                
                // Binder Name with profile and settings buttons
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        Text(vm.binderName)
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            showProfile = true
                        } label: {
                            Image(systemName: "person.circle")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Text("\(vm.selectedBinder.displayName) • \(vm.selectedTCG.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(isTransitioning ? 0.0 : subtitleOpacity)
                .animation(.easeOut(duration: 0.3), value: isTransitioning)
                .padding(.top, 8)
                
                // TCG Selection Button
                Button {
                    showTCGSelection = true
                } label: {
                    HStack(spacing: 8) {
                        Image(vm.selectedTCG.logoImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                        
                        Text("Change Game: \(vm.selectedTCG.displayName)")
                            .font(.subheadline.weight(.medium))
                        
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
                .opacity(isTransitioning ? 0.0 : subtitleOpacity)
                .animation(.easeOut(duration: 0.3), value: isTransitioning)
            }
            .padding(.top, -50)
        }
        .onAppear {
            // Animate title appearance
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                titleOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                subtitleOpacity = 1.0
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(selectedBackground: selectedBackground)
                .preferredColorScheme(selectedColorScheme.colorScheme)
        }
        .sheet(isPresented: $showTCGSelection) {
            TCGSelectionView()
                .preferredColorScheme(selectedColorScheme.colorScheme)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(selectedBackground: $selectedBackground, selectedColorScheme: $selectedColorScheme)
                .preferredColorScheme(selectedColorScheme.colorScheme)
        }
    }
    
    // MARK: - Animation Functions
    
    private func triggerExpansionAnimation(color: Color) {
        // The matchedGeometryEffect will handle the transformation
        // This function can be simplified or potentially removed
    }
}

// MARK: - TCG Selection Popup
struct TCGSelectionView: View {
    @EnvironmentObject var vm: BinderViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground(selectedBackground: .original)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Select Trading Card Game")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.top)
                    
                    VStack(spacing: 20) {
                        ForEach(TCGType.allCases, id: \.self) { tcgType in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    vm.switchTCG(to: tcgType)
                                }
                                dismiss()
                            } label: {
                                HStack(spacing: 16) {
                                    // TCG Logo
                                    ZStack {
                                        Circle()
                                            .fill(Color(.systemGray6))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(tcgType.logoImageName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 45, height: 45)
                                            .clipShape(Circle())
                                    }
                                    
                                    // TCG Name
                                    Text(tcgType.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    // Selection indicator
                                    if vm.selectedTCG == tcgType {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(vm.selectedTCG == tcgType ? .blue : .clear, lineWidth: 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Game Selection")
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
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var selectedBackground: BackgroundType
    @Binding var selectedColorScheme: AppColorScheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground(selectedBackground: .original)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Appearance Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "paintbrush")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                Text("Appearance")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            // Color Scheme Section
                            VStack(spacing: 12) {
                                ForEach(AppColorScheme.allCases, id: \.self) { colorScheme in
                                    Button {
                                        selectedColorScheme = colorScheme
                                    } label: {
                                        HStack(spacing: 16) {
                                            // Color scheme icon
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .frame(width: 60, height: 40)
                                                    .overlay {
                                                        switch colorScheme {
                                                        case .system:
                                                            HStack(spacing: 0) {
                                                                Rectangle()
                                                                    .fill(Color.black)
                                                                Rectangle()
                                                                    .fill(Color.white)
                                                            }
                                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        case .light:
                                                            Rectangle()
                                                                .fill(Color.white)
                                                                .overlay(
                                                                    RoundedRectangle(cornerRadius: 12)
                                                                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                                                                )
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        case .dark:
                                                            Rectangle()
                                                                .fill(Color.black)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        }
                                                    }
                                            }
                                            
                                            // Color scheme name
                                            Text(colorScheme.displayName)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            
                                            Spacer()
                                            
                                            // Selection indicator
                                            if selectedColorScheme == colorScheme {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(.blue)
                                            } else {
                                                Image(systemName: "circle")
                                                    .font(.title3)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        .background {
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(.ultraThinMaterial)
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(selectedColorScheme == colorScheme ? .blue : .clear, lineWidth: 2)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Background Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "photo")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                Text("Background")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                ForEach(BackgroundType.allCases, id: \.self) { backgroundType in
                                    Button {
                                        selectedBackground = backgroundType
                                    } label: {
                                        HStack(spacing: 16) {
                                            // Background preview
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .frame(width: 60, height: 40)
                                                    .overlay {
                                                        if backgroundType == .original {
                                                            LinearGradient(
                                                                colors: [
                                                                    Color("BinderGreen").opacity(0.55),
                                                                    Color("BinderGreen").opacity(0.35)
                                                                ],
                                                                startPoint: .topLeading, 
                                                                endPoint: .bottomTrailing
                                                            )
                                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        } else if backgroundType == .potential {
                                                            Image("potential background")
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: 60, height: 40)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        } else {
                                                            Image("bakcground2")
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: 60, height: 40)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        }
                                                    }
                                            }
                                            
                                            // Background name
                                            Text(backgroundType.displayName)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            
                                            Spacer()
                                            
                                            // Selection indicator
                                            if selectedBackground == backgroundType {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(.blue)
                                            } else {
                                                Image(systemName: "circle")
                                                    .font(.title3)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        .background {
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(.ultraThinMaterial)
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(selectedBackground == backgroundType ? .blue : .clear, lineWidth: 2)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Settings")
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
}

// MARK: - Binder Carousel Component

struct BinderCarouselView: View {
    @EnvironmentObject var vm: BinderViewModel
    @Binding var showBinder: Bool
    let binderTransition: Namespace.ID
    @Binding var isTransitioning: Bool
    let onExpansionTrigger: (Color) -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var currentIndex: Int = 0
    @State private var isPressed: Bool = false
    @GestureState private var isLongPressing = false
    @State private var isTransforming: Bool = false
    
    private let binders = BinderType.allCases
    private let binderWidth: CGFloat = 280
    private let binderSpacing: CGFloat = 80
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()
                ZStack {
                    ForEach(Array(binders.enumerated()), id: \.offset) { index, binder in
                        BinderCard(
                            binder: binder,
                            isSelected: vm.selectedBinder == binder,
                            isTransforming: isTransforming && vm.selectedBinder == binder,
                            binderTransition: binderTransition,
                            onClick: {
                                if vm.selectedBinder == binder {
                                    // If already selected, start transformation with automatic navigation
                                    isTransforming = true
                                    isTransitioning = true
                                    onExpansionTrigger(binder.color)
                                    
                                    // Trigger navigation change immediately for automatic transition
                                    withAnimation(.easeInOut(duration: 0.6)) {
                                        showBinder = true
                                    }
                                    
                                    // Reset states after transition
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                        isTransforming = false
                                        isTransitioning = false
                                    }
                                } else {
                                    // If not selected, switch to this binder (circular navigation)
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        vm.switchBinder(to: binder)
                                        currentIndex = index
                                    }
                                }
                            }
                        )
                        .scaleEffect(scaleForBinder(at: index))
                        .opacity(opacityForBinder(at: index))
                        .offset(x: offsetForBinder(at: index), y: yOffsetForBinder(at: index))
                        .zIndex(zIndexForBinder(at: index))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: vm.selectedBinder)
                    }
                }
                .frame(width: binderWidth)
                Spacer()
            }
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 30
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        
                        // Determine direction based on drag distance and velocity
                        let shouldMoveLeft = value.translation.width < -threshold || velocity < -100
                        let shouldMoveRight = value.translation.width > threshold || velocity > 100
                        
                        if shouldMoveRight {
                            // Swipe right - go to previous binder (circular)
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentIndex = (currentIndex - 1 + binders.count) % binders.count
                                vm.switchBinder(to: binders[currentIndex])
                            }
                        } else if shouldMoveLeft {
                            // Swipe left - go to next binder (circular)
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentIndex = (currentIndex + 1) % binders.count
                                vm.switchBinder(to: binders[currentIndex])
                            }
                        }
                        
                        // Always reset drag offset with animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
            )
        }
        .frame(height: 350)
        .onAppear {
            currentIndex = binders.firstIndex(of: vm.selectedBinder) ?? 0
        }
    }
    
    // Helper function to calculate circular distance
    private func circularDistance(from sourceIndex: Int, to targetIndex: Int, totalCount: Int) -> Int {
        var distance = targetIndex - sourceIndex
        
        // Normalize to shortest path around the circle
        if distance > totalCount / 2 {
            distance -= totalCount
        } else if distance < -totalCount / 2 {
            distance += totalCount
        }
        
        return distance
    }
    
    private func offsetForBinder(at index: Int) -> CGFloat {
        let selectedIndex = binders.firstIndex(of: vm.selectedBinder) ?? 0
        let relativeIndex = circularDistance(from: selectedIndex, to: index, totalCount: binders.count)
        
        let spacing: CGFloat = 60
        let baseOffset = CGFloat(relativeIndex) * spacing
        return baseOffset + dragOffset * 0.5
    }
    
    private func scaleForBinder(at index: Int) -> CGFloat {
        let selectedIndex = binders.firstIndex(of: vm.selectedBinder) ?? 0
        let relativeIndex = circularDistance(from: selectedIndex, to: index, totalCount: binders.count)
        let absRelativeIndex = abs(relativeIndex)
        
        switch absRelativeIndex {
        case 0: return 1.0 // Front binder - full size
        case 1: return 0.9 // Second binder - slightly smaller
        default: return 0.8 // Back binders - smaller
        }
    }
    
    private func opacityForBinder(at index: Int) -> Double {
        let selectedIndex = binders.firstIndex(of: vm.selectedBinder) ?? 0
        let relativeIndex = circularDistance(from: selectedIndex, to: index, totalCount: binders.count)
        let absRelativeIndex = abs(relativeIndex)
        
        switch absRelativeIndex {
        case 0: return 1.0 // Front binder - fully visible
        case 1: return 0.8 // Second binder - slightly faded
        default: return 0.6 // Back binders - more faded
        }
    }
    
    private func yOffsetForBinder(at index: Int) -> CGFloat {
        let selectedIndex = binders.firstIndex(of: vm.selectedBinder) ?? 0
        let relativeIndex = circularDistance(from: selectedIndex, to: index, totalCount: binders.count)
        let absRelativeIndex = abs(relativeIndex)
        
        switch absRelativeIndex {
        case 0: return 0 // Front binder - no vertical offset
        case 1: return 10 // Second binder - slightly back
        default: return 20 // Back binders - further back
        }
    }
    
    private func zIndexForBinder(at index: Int) -> Double {
        let selectedIndex = binders.firstIndex(of: vm.selectedBinder) ?? 0
        let relativeIndex = circularDistance(from: selectedIndex, to: index, totalCount: binders.count)
        
        // Front binder has highest z-index, decreasing as we go back
        return Double(binders.count - abs(relativeIndex))
    }
}

struct BinderCard: View {
    let binder: BinderType
    let isSelected: Bool
    let isTransforming: Bool
    let binderTransition: Namespace.ID
    let onClick: () -> Void
    
    @State private var isPressed: Bool = false
    @State private var selectionScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Binder Shadow
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(isSelected ? 0.2 : 0.1))
                .frame(width: 280, height: 350)
                .offset(x: 8, y: 12)
            
            // Binder Base - zoom source for selected binder
            RoundedRectangle(cornerRadius: 20)
                .fill(binder.color)
                .frame(width: 280, height: 350)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.15), lineWidth: 2)
                )
                .if(isSelected) { view in
                    view.navigationTransition(.zoom(sourceID: "selectedBinder", in: binderTransition))
                }
            
            // Binder Image
            Image(binder.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 330)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Selection indicator
            if isSelected {
                VStack {
                    Spacer()
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 16, height: 16)
                        .padding(.bottom, 20)
                }
            }
        }
        .scaleEffect(isPressed ? 1.1 : (isSelected ? selectionScale : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectionScale)
        .onTapGesture {
            // Quick press animation
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            // Card scale animation for selection feedback
            if !isTransforming {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    selectionScale = 1.05
                }
            }
            
            // Call the click action
            onClick()
            
            // Reset animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPressed = false
                }
            }
            
            if !isTransforming {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectionScale = 1.0
                    }
                }
            }
        }
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                // Expand animation when becoming selected
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    selectionScale = 1.05
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectionScale = 1.0
                    }
                }
            }
        }
    }
}
#Preview {
    @State var showBinder = false
    @Namespace var previewTransition
    
    // Create a simple preview version
    @StateObject var previewVM = {
        let vm = BinderViewModel()
        return vm
    }()
    
    return LandingView(
        showBinder: $showBinder, 
        selectedBackground: .constant(.original),
        selectedColorScheme: .constant(.system),
        binderTransition: previewTransition
    )
    .environmentObject(previewVM)
    .preferredColorScheme(.light)
}
