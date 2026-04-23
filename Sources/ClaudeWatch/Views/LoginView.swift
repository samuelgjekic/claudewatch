import SwiftUI
import WebKit

struct LoginView: View {
    @ObservedObject var auth: AuthService

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(spacing: 6) {
                Text("ClaudeWatch")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text("Monitor your Claude usage in real time")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }

            VStack(spacing: 4) {
                Text("Sign in with your Claude account")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                Text("to see session, weekly, and Sonnet usage limits.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }

            if auth.isLoggingIn {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Complete sign-in in the browser window...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                Button(action: { auth.startLogin() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 12))
                        Text("Connect to Claude")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }

            if let error = auth.loginError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                    Text(error)
                        .font(.system(size: 10))
                        .lineLimit(2)
                }
                .foregroundStyle(.red)
                .padding(8)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 16)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(width: 370, height: 340)
        .background(Color(white: 0.08))
    }
}
