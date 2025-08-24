import SwiftUI
import Supabase

enum AuthMode: String, CaseIterable { case signIn = "Sign In", register = "Register" }
enum AuthMethod: String, CaseIterable { case password = "Password", link = "Email Link" }

struct AuthView: View {
  @State private var mode: AuthMode = .signIn
  private let method: AuthMethod = .password // Always use password method

  @State private var email = ""
  @State private var password = ""
  @State private var username = ""   // used only when registering with password

  @State private var isLoading = false
  @State private var message: String?

  var body: some View {
    ZStack {
      // Background to match the app
      LinearGradient(
        gradient: Gradient(colors: [Color.black.opacity(0.8), Color.blue.opacity(0.6)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
      
      // Main content
      ScrollView {
        VStack(spacing: 32) {
          Spacer(minLength: 60)
          
          // App Logo
          Image("tcg-binder-title")
            .resizable()
            .scaledToFit()
            .frame(height: 80)
            .padding(.horizontal, 40)
          
          VStack(spacing: 24) {
            // Mode Toggle
            VStack(spacing: 12) {
              Text("Choose Action")
                .font(.headline)
                .foregroundColor(.white)
              
              Picker("Mode", selection: $mode) {
                ForEach(AuthMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
              }
              .pickerStyle(.segmented)
              .padding(.horizontal, 20)
            }
            
            
            // Input Fields
            VStack(spacing: 16) {
              // Email Field
              VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                  .font(.subheadline)
                  .foregroundColor(.white.opacity(0.8))
                
                TextField("Enter your email", text: $email)
                  .textContentType(.emailAddress)
                  .textInputAutocapitalization(.never)
                  .autocorrectionDisabled()
                  .padding(.horizontal, 16)
                  .padding(.vertical, 12)
                  .background(Color.white.opacity(0.1))
                  .cornerRadius(12)
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .stroke(Color.white.opacity(0.3), lineWidth: 1)
                  )
              }
              
              // Password Field
              VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                  .font(.subheadline)
                  .foregroundColor(.white.opacity(0.8))
                
                SecureField("Enter password (min 6 characters)", text: $password)
                  .textContentType(.password)
                  .padding(.horizontal, 16)
                  .padding(.vertical, 12)
                  .background(Color.white.opacity(0.1))
                  .cornerRadius(12)
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .stroke(Color.white.opacity(0.3), lineWidth: 1)
                  )
              }
              
              // Username Field
              if mode == .register {
                VStack(alignment: .leading, spacing: 8) {
                  Text("Username")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                  
                  TextField("Choose a username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                      RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
              }
            }
            .padding(.horizontal, 20)
            
            // Action Button
            VStack(spacing: 16) {
              Button(action: { Task { await go() } }) {
                HStack {
                  if isLoading {
                    ProgressView()
                      .progressViewStyle(CircularProgressViewStyle(tint: .white))
                      .scaleEffect(0.8)
                  }
                  Text(ctaTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                  LinearGradient(
                    gradient: Gradient(colors: canSubmit && !isLoading ? 
                      [Color.blue, Color.purple] : 
                      [Color.gray.opacity(0.5), Color.gray.opacity(0.3)]
                    ),
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
              }
              .disabled(!canSubmit || isLoading)
              .padding(.horizontal, 20)
              
              // Message Display
              if let message {
                Text(message)
                  .font(.subheadline)
                  .foregroundColor(.white.opacity(0.9))
                  .multilineTextAlignment(.center)
                  .padding(.horizontal, 20)
                  .padding(.vertical, 12)
                  .background(Color.white.opacity(0.1))
                  .cornerRadius(8)
                  .padding(.horizontal, 20)
              }
            }
          }
          
          Spacer(minLength: 40)
        }
      }
    }
  }

  // MARK: - Helpers

  private var ctaTitle: String {
    switch mode {
    case .signIn:   return "Sign In"
    case .register: return "Create Account"
    }
  }

  private var canSubmit: Bool {
    guard !email.isEmpty else { return false }
    if password.count < 6 { return false }
    if mode == .register && username.trimmingCharacters(in: .whitespaces).isEmpty { return false }
    return true
  }

  private func go() async {
    isLoading = true; defer { isLoading = false }
    message = nil

    switch mode {
    case .signIn:
      await signInWithPassword()

    case .register:
      await registerWithPassword()
    }
  }

  // MARK: - Flows

  /// Register with email+password. Supabase will email a verification link.
    private func registerWithPassword() async {
      do {
        let meta: [String: AnyJSON] = [
          "username": .string(username)   // <-- wrap as AnyJSON
        ]

        _ = try await supabase.auth.signUp(
          email: email,
          password: password,
          // data: meta,
          redirectTo: URL(string: "tcgbinder://auth-callback")!
        )

        message = "Account created. Check your email to verify."
      } catch {
        message = error.localizedDescription
      }
    }

  /// Sign in with email+password (will fail if email not verified and confirmation is required).
  private func signInWithPassword() async {
    do {
        try await supabase.auth.signIn(email: email,
                                       password: password
      )
    } catch {
      let msg = error.localizedDescription
      if msg.localizedCaseInsensitiveContains("confirm") ||
         msg.localizedCaseInsensitiveContains("not confirmed") {
        message = "Please verify your email first. We sent you a link."
      } else if msg.localizedCaseInsensitiveContains("invalid login") ||
                msg.localizedCaseInsensitiveContains("invalid credentials") {
        message = "Invalid email or password."
      } else {
        message = msg
      }
    }
  }

}

