import SwiftUI
import MiniVPNCore

/// 7.2 Register. Email + password + confirm. Client-side mismatch check before
/// enabling the button; backend errors surfaced inline.
struct RegisterView: View {
    @ObservedObject var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""

    private var passwordsMatch: Bool { !confirm.isEmpty && confirm == password }
    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6 && passwordsMatch && !auth.isLoading
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Create account").font(.title2).fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("start your subscription").font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Email", text: $email)
                .textContentType(.username).keyboardType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            SecureField("Confirm password", text: $confirm)
                .textContentType(.newPassword)
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.red, lineWidth: (!confirm.isEmpty && !passwordsMatch) ? 1 : 0)
                )

            if !confirm.isEmpty && !passwordsMatch {
                Text("两次输入的密码不一致").font(.footnote).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let err = auth.errorMessage {
                Text(err).font(.footnote).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await auth.register(email: email, password: password) }
            } label: {
                if auth.isLoading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text("Sign up").fontWeight(.medium).frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 13)
            .background(canSubmit ? AnyShapeStyle(.tint) : AnyShapeStyle(.gray.opacity(0.4)),
                        in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .disabled(!canSubmit)

            Spacer()
        }
        .padding(24)
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
    }
}
