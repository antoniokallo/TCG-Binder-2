import SwiftUI
import Supabase

enum AuthMode: String, CaseIterable { case signIn = "Sign In", register = "Register" }
enum AuthMethod: String, CaseIterable { case password = "Password", link = "Email Link" }

struct AuthView: View {
  @State private var mode: AuthMode = .signIn
  @State private var method: AuthMethod = .password

  @State private var email = ""
  @State private var password = ""
  @State private var username = ""   // used only when registering with password

  @State private var isLoading = false
  @State private var message: String?

  var body: some View {
    Form {
      // Toggles
      Section {
        Picker("Mode", selection: $mode) {
          ForEach(AuthMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented)

        Picker("Method", selection: $method) {
          ForEach(AuthMethod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented)
      }

      // Fields
      Section {
        TextField("Email", text: $email)
          .textContentType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        if method == .password {
          SecureField("Password (min 6)", text: $password)
            .textContentType(.password)
        }

        if mode == .register && method == .password {
          TextField("Username", text: $username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
      }

      // Action
      Section {
        Button(action: { Task { await go() } }) {
          Text(ctaTitle)
        }
        .disabled(!canSubmit || isLoading)

        if isLoading { ProgressView() }
      }

      if let message {
        Section { Text(message).font(.footnote).foregroundColor(.secondary) }
      }
    }
  }

  // MARK: - Helpers

  private var ctaTitle: String {
    switch (mode, method) {
    case (.signIn, .password):   return "Sign in with Password"
    case (.register, .password): return "Create Account"
    case (.signIn, .link):       return "Send Magic Link"
    case (.register, .link):     return "Send Registration Link"
    }
  }

  private var canSubmit: Bool {
    guard !email.isEmpty else { return false }
    if method == .password {
      if password.count < 6 { return false }
      if mode == .register && username.trimmingCharacters(in: .whitespaces).isEmpty { return false }
    }
    return true
  }

  private func go() async {
    isLoading = true; defer { isLoading = false }
    message = nil

    switch (mode, method) {
    case (.signIn, .password):
      await signInWithPassword()

    case (.register, .password):
      await registerWithPassword()

    case (.signIn, .link):
      await sendMagicLink(createUser: false)

    case (.register, .link):
      await sendMagicLink(createUser: true)
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

  /// Magic-link flow (works for both sign-in and register).
  private func sendMagicLink(createUser: Bool) async {
    do {
      try await supabase.auth.signInWithOTP(
        email: email,
        redirectTo: URL(string: "tcgbinder://auth-callback")!
      )
      // NOTE: Older Swift SDK doesn't expose shouldCreateUser; Supabase will create
      // the account on first confirmation if it doesn't exist.
      message = "Check your email for the link."
    } catch {
      message = error.localizedDescription
    }
  }
}

