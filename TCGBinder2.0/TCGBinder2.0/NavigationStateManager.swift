//
//  NavigationStateManager.swift
//  TCGBinder2.0
//
//  Manages navigation state and context-aware visibility
//

import SwiftUI
import Combine

@MainActor
class NavigationStateManager: ObservableObject {
    @Published var shouldShowTabBar = true
    @Published var isSignedIn = true // For demo purposes, set to true
    
    // Context-aware visibility control
    func hideTabBar() {
        withAnimation(.easeInOut(duration: 0.3)) {
            shouldShowTabBar = false
        }
    }
    
    func showTabBar() {
        withAnimation(.easeInOut(duration: 0.3)) {
            shouldShowTabBar = true
        }
    }
    
    // Hide tab bar for specific flows
    func enterFullScreenMode() {
        hideTabBar()
    }
    
    func exitFullScreenMode() {
        if isSignedIn {
            showTabBar()
        }
    }
}

// Environment key for navigation state
private struct NavigationStateKey: EnvironmentKey {
    @MainActor
    static let defaultValue = NavigationStateManager()
}

extension EnvironmentValues {
    var navigationState: NavigationStateManager {
        get { self[NavigationStateKey.self] }
        set { self[NavigationStateKey.self] = newValue }
    }
}