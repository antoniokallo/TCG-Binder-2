import SwiftUI
import Supabase

@main
struct TCGBinder2_0App: App {
  var body: some Scene {
    WindowGroup {
      RootView()
        // Handles tcgbinder://auth-callback?code=... (signup confirm & magic-link)
        .onOpenURL { url in
          Task {
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            guard let code = comps?.queryItems?.first(where: { $0.name == "code" })?.value else {
              print("No 'code' in callback URL:", url)
              return
            }
            do {
              try await supabase.auth.exchangeCodeForSession(authCode: code)

              // Mark profile as active once we have a session (email verified)
              if let uid = try? await supabase.auth.session.user.id {
                try? await supabase.database
                  .from("profiles")
                  .update(["status": "active"])
                  .eq("id", value: uid.uuidString)
                  .execute()
              }
            } catch {
              print("Exchange failed:", error)
            }
          }
        }
    }
  }
}

struct RootView: View {
  @State private var session: Session?
  @State private var showLoadingTransition = false
  @State private var showMainApp = false

  var body: some View {
    Group {
      if session == nil {
        AuthView()
      } else if showLoadingTransition {
        LoadingTransitionView {
          // Complete loading and show main app
          withAnimation(.easeInOut(duration: 0.5)) {
            showLoadingTransition = false
            showMainApp = true
          }
        }
      } else if showMainApp {
        ContentView()
      } else {
        // This handles the initial session state
        ContentView()
      }
    }
    .task {
      for await (event, newSession) in await supabase.auth.authStateChanges {
        await MainActor.run {
          switch event {
          case .signedIn:  
            self.session = newSession
            // Trigger loading transition for fresh sign-ins
            if !showMainApp {
              showLoadingTransition = true
            }
          case .signedOut: 
            self.session = nil
            showLoadingTransition = false
            showMainApp = false
          default: 
            // Handle initial session - show main app directly without loading screen
            if event == .initialSession && newSession != nil {
              self.session = newSession
              showMainApp = true
            }
          }
        }
      }
    }
  }
}

