//
//  EnhancedSettingsView.swift
//  TCGBinder2.0
//
//  Enhanced settings view for the navbar
//

import SwiftUI

struct EnhancedSettingsView: View {
    @EnvironmentObject var vm: BinderViewModel
    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system
    @AppStorage("selectedBackground") private var selectedBackground: BackgroundType = .potential
    
    var body: some View {
        NavigationView {
            List {
                // Current Binder Section
                Section("Current Binder") {
                    if let selectedBinder = vm.selectedUserBinder {
                        HStack {
                            Circle()
                                .fill(selectedBinder.color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedBinder.name)
                                    .font(.headline)
                                
                                if let game = selectedBinder.game {
                                    Text(TCGType(rawValue: game)?.displayName ?? "Unknown Game")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No game assigned")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                                .frame(width: 40, height: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No Binder Selected")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Create a binder from the home tab")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Game Section
                Section("Game") {
                    HStack {
                        Image(vm.selectedTCG.logoImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        
                        Text(vm.selectedTCG.displayName)
                        
                        Spacer()
                        
                        Text("Active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Appearance Section
                Section("Appearance") {
                    HStack {
                        Image(systemName: colorSchemeIcon)
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Theme")
                        
                        Spacer()
                        
                        Picker("Color Scheme", selection: $appColorScheme) {
                            ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                                Text(scheme.displayName).tag(scheme)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        Image(systemName: "photo")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Background")
                        
                        Spacer()
                        
                        Picker("Background", selection: $selectedBackground) {
                            ForEach(BackgroundType.allCases, id: \.self) { background in
                                Text(background.displayName).tag(background)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // Statistics Section
                Section("Statistics") {
                    StatRowView(icon: "rectangle.stack", title: "Total Cards", value: "\(vm.sets.flatMap { $0.cards }.count)")
                    StatRowView(icon: "folder", title: "Sets", value: "\(vm.sets.count)")
                    StatRowView(icon: "book.closed", title: "Binders Owned", value: "\(vm.binderNumbers.count)")
                }
                
                // Actions Section
                Section("Actions") {
                    Button(role: .destructive) {
                        vm.clearAllData()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear All Data")
                        }
                    }
                }
                
                // App Info Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Clear All Data", isPresented: $vm.showingClearDataConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                Task {
                    await vm.confirmClearAllData()
                }
            }
        } message: {
            Text("This will permanently delete all your cards, binders, and data from both the app and cloud storage. This action cannot be undone.")
        }
    }
    
    private var colorSchemeIcon: String {
        switch appColorScheme {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
}

struct StatRowView: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}


#Preview {
    EnhancedSettingsView()
        .environmentObject(BinderViewModel())
}