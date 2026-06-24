import SwiftUI
import MiniVPNCore

/// 7.1 Login. Email + password → AuthViewModel.login. Errors surfaced inline.
struct LoginView: View {
    @ObservedObject var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 46)).foregroundStyle(.tint)
            Text("Welcome back").font(.title2).fontWeight(.medium)
            Text("sign in to continue").font(.footnote).foregroundStyle(.secondary)

            VStack(spacing: 10) {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Group {
                        if showPassword { TextField("Password", text: $password) }
                        else { SecureField("Password", text: $password) }
                    }
                    .textContentType(.password)
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                }
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            if let err = auth.errorMessage {
                Text(err).font(.footnote).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await auth.login(email: email, password: password) }
            } label: {
                if auth.isLoading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text("Log in").fontWeight(.medium).frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 13)
            .background(.tint, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .disabled(auth.isLoading || email.isEmpty || password.isEmpty)

            NavigationLink("New here? Create account") {
                RegisterView(auth: auth)
            }
            .font(.subheadline)

            Spacer()
        }
        .padding(24)
    }
}
