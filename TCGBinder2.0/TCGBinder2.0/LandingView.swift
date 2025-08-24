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

struct LandingView: View {
    @Binding var showBinder: Bool
    @Binding var selectedBackground: BackgroundType
    @Binding var selectedColorScheme: AppColorScheme
    @EnvironmentObject var vm: BinderViewModel
    let binderTransition: Namespace.ID
    @State private var binderScale: CGFloat = 1.0
    @State private var titleOpacity: Double = 0.0
    @State private var titleScale: CGFloat = 0.8
    @State private var subtitleOpacity: Double = 0.0
    @State private var isTransitioning: Bool = false
    @State private var bindersVisible: Bool = false // Control binder visibility for entrance
    @State private var contentTopOffset: CGFloat = 100 // Start below, slide up to final position
    
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
                    .scaleEffect(titleScale)
                    .opacity(isTransitioning ? 0.0 : titleOpacity)
                    .animation(.easeOut(duration: 0.3), value: isTransitioning)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: titleScale)
                    .onLongPressGesture(minimumDuration: 3.0) {
                        // Hidden developer feature: long press title to clear all data
                        vm.clearAllData()
                    }
                
                // Binder Carousel - only show when ready for entrance
                if bindersVisible {
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
                }
                
                
            }
            .offset(y: contentTopOffset)
            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: contentTopOffset)
        }
        .onAppear {
            // Animate title appearance with bounce
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                titleOpacity = 1.0
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0).delay(0.3)) {
                titleScale = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                subtitleOpacity = 1.0
            }
            
            // Smoothly slide content from below to final position after title appears  
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.8)) {
                contentTopOffset = -50
            }
            
            // Show binders after slide animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                bindersVisible = true
            }
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
struct LandingSettingsView: View {
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
    
    private var binders: [UserBinder] { vm.userBinders }
    private let binderWidth: CGFloat = 280
    private let binderSpacing: CGFloat = 80
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()
                ZStack {
                    ForEach(Array(binders.enumerated()), id: \.offset) { index, userBinder in
                        let isBinderSelected = vm.selectedUserBinder?.id == userBinder.id
                        let isBinderTransforming = isTransforming && isBinderSelected
                        let binderEntranceDelay = Double(index) * 0.2
                        
                        BinderCard(
                            userBinder: userBinder,
                            isSelected: isBinderSelected,
                            isTransforming: isBinderTransforming,
                            binderTransition: binderTransition,
                            onClick: { handleBinderCardTap(userBinder: userBinder, index: index) },
                            entranceDelay: binderEntranceDelay
                        )
                        .modifier(BinderCardLayoutModifier(
                            scale: scaleForBinder(at: index),
                            opacity: opacityForBinder(at: index),
                            offsetX: offsetForBinder(at: index),
                            offsetY: yOffsetForBinder(at: index),
                            zIndex: zIndexForBinder(at: index)
                        ))
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
                        
                        if shouldMoveRight && !binders.isEmpty {
                            // Swipe right - go to previous binder (circular) - NO preloading
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentIndex = (currentIndex - 1 + binders.count) % binders.count
                                vm.selectUserBinder(binders[currentIndex]) // Just visual selection, no card loading
                            }
                        } else if shouldMoveLeft && !binders.isEmpty {
                            // Swipe left - go to next binder (circular) - NO preloading
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentIndex = (currentIndex + 1) % binders.count
                                vm.selectUserBinder(binders[currentIndex]) // Just visual selection, no card loading
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
            if let selectedBinder = vm.selectedUserBinder {
                currentIndex = binders.firstIndex { $0.id == selectedBinder.id } ?? 0
            }
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
        let selectedIndex: Int
        if let selectedBinder = vm.selectedUserBinder {
            selectedIndex = binders.firstIndex { $0.id == selectedBinder.id } ?? 0
        } else {
            selectedIndex = 0
        }
        let relativeIndex = circularDistance(from: selectedIndex, to: index, totalCount: binders.count)
        
        let spacing: CGFloat = 60
        let baseOffset = CGFloat(relativeIndex) * spacing
        return baseOffset + dragOffset * 0.5
    }
    
    private func scaleForBinder(at index: Int) -> CGFloat {
        let selectedIndex: Int
        if let selectedBinder = vm.selectedUserBinder {
            selectedIndex = binders.firstIndex { $0.id == selectedBinder.id } ?? 0
        } else {
            selectedIndex = 0
        }
        let relativeIndex = circularDistance(from: selectedIndex, to: index, totalCount: binders.count)
        let absRelativeIndex = abs(relativeIndex)
        
        switch absRelativeIndex {
        case 0: return 1.0 // Front binder - full size
        case 1: return 0.9 // Second binder - slightly smaller
        default: return 0.8 // Back binders - smaller
        }
    }
    
    private func opacityForBinder(at index: Int) -> Double {
        let selectedIndex: Int
        if let selectedBinder = vm.selectedUserBinder {
            selectedIndex = binders.firstIndex { $0.id == selectedBinder.id } ?? 0
        } else {
            selectedIndex = 0
        }
        let relativeIndex = circularDistance(from: selectedIndex, to: index, totalCount: binders.count)
        let absRelativeIndex = abs(relativeIndex)
        
        switch absRelativeIndex {
        case 0: return 1.0 // Front binder - fully visible
        case 1: return 0.8 // Second binder - slightly faded
        default: return 0.6 // Back binders - more faded
        }
    }
    
    private func yOffsetForBinder(at index: Int) -> CGFloat {
        let selectedIndex: Int
        if let selectedBinder = vm.selectedUserBinder {
            selectedIndex = binders.firstIndex { $0.id == selectedBinder.id } ?? 0
        } else {
            selectedIndex = 0
        }
        let relativeIndex = circularDistance(from: selectedIndex, to: index, totalCount: binders.count)
        let absRelativeIndex = abs(relativeIndex)
        
        switch absRelativeIndex {
        case 0: return 0 // Front binder - no vertical offset
        case 1: return 10 // Second binder - slightly back
        default: return 20 // Back binders - further back
        }
    }
    
    private func zIndexForBinder(at index: Int) -> Double {
        let selectedIndex: Int
        if let selectedBinder = vm.selectedUserBinder {
            selectedIndex = binders.firstIndex { $0.id == selectedBinder.id } ?? 0
        } else {
            selectedIndex = 0
        }
        let relativeIndex = circularDistance(from: selectedIndex, to: index, totalCount: binders.count)
        
        // Front binder has highest z-index, decreasing as we go back
        return Double(binders.count - abs(relativeIndex))
    }
    
    // Extract complex onClick logic to avoid compiler type-checking issues
    private func handleBinderCardTap(userBinder: UserBinder, index: Int) {
        if vm.selectedUserBinder?.id == userBinder.id {
            // User explicitly tapped to open this binder - load cards now!
            vm.openUserBinder(userBinder)
            
            // Start transformation with automatic navigation
            isTransforming = true
            isTransitioning = true
            onExpansionTrigger(Color.black) // Use black as default color
            
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
            // If not selected, just switch visually - NO preloading!
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                vm.selectUserBinder(userBinder)
                currentIndex = index
            }
        }
    }
}

// Custom ViewModifier to simplify complex modifier chains
struct BinderCardLayoutModifier: ViewModifier {
    let scale: CGFloat
    let opacity: Double
    let offsetX: CGFloat
    let offsetY: CGFloat
    let zIndex: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: offsetX, y: offsetY)
            .zIndex(zIndex)
    }
}

struct BinderCard: View {
    let userBinder: UserBinder
    let isSelected: Bool
    let isTransforming: Bool
    let binderTransition: Namespace.ID
    let onClick: () -> Void
    let entranceDelay: Double // Add entrance delay parameter
    
    @State private var isPressed: Bool = false
    @State private var selectionScale: CGFloat = 1.0
    // Entrance animation states
    @State private var entranceScale: CGFloat = 0.3
    @State private var entranceOpacity: Double = 0.0
    @State private var entranceOffset: CGFloat = 100
    
    // Helper computed properties
    private var binderColor: Color {
        // Use the database color from the UserBinder model
        return userBinder.color
    }
    
    private var binderImageName: String {
        let assignedValue = Int(userBinder.assigned_value)
        let imageIndex = (assignedValue - 1) % 3 // Rotate through 3 images
        
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
        case "pokemon":
            return "pokemon"
        case "yugioh":
            return "yugioh"
        case "one_piece":
            return "logo_op"
        default:
            return "tcg-binder-title"
        }
    }
    
    var body: some View {
        ZStack {
            // Binder Shadow
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(isSelected ? 0.2 : 0.1))
                .frame(width: 280, height: 350)
                .offset(x: 8, y: 12)
            
            // Binder Base - zoom source for selected binder
            RoundedRectangle(cornerRadius: 20)
                .fill(binderColor)
                .frame(width: 280, height: 350)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.15), lineWidth: 2)
                )
                .if(isSelected) { view in
                    view.navigationTransition(.zoom(sourceID: "selectedBinder", in: binderTransition))
                }
            
            // Binder Image
            Image(binderImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 330)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // TCG Logo at the top
            VStack {
                HStack {
                    Spacer()
                    Image(tcgImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 40)
                        .if(binderImageName == "binder2-black") { view in
                            view
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                        }
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                }
                Spacer()
            }
            
            // Binder Name Label
            VStack {
                Spacer()
                Text(userBinder.name)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .padding(.bottom, 20)
            }
        }
        // Apply entrance animations
        .scaleEffect(entranceScale * (isPressed ? 1.1 : (isSelected ? selectionScale : 1.0)))
        .opacity(entranceOpacity)
        .offset(y: entranceOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectionScale)
        // Entrance animation with bouncy spring
        .animation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0), value: entranceScale)
        .animation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0), value: entranceOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0), value: entranceOffset)
        .onAppear {
            // Trigger bouncy entrance with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + entranceDelay) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0)) {
                    entranceScale = 1.0
                    entranceOpacity = 1.0
                    entranceOffset = 0
                }
            }
        }
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
