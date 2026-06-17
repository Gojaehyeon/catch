import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var working = false
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle().fill(Theme.coral.opacity(0.18)).frame(width: 160, height: 160)
                Text("🫳")
                    .font(.system(size: 86))
                    .rotationEffect(.degrees(bounce ? -8 : 8))
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: bounce)
            }

            Text("Catch")
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)
            Text("잡은 사물을 모으고, 나누고, 발견해요 ✨")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink.opacity(0.55))
                .padding(.top, 6)

            Spacer()

            Button {
                working = true
                Task { await auth.signInWithApple(); working = false }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                    Text("Apple로 시작하기").fontWeight(.bold)
                }
            }
            .buttonStyle(CuteButtonStyle(bg: Theme.ink, fg: .white))
            .disabled(working)
            .padding(.horizontal, 28)

            Text("계속하면 약관 및 개인정보 처리방침에 동의해요")
                .font(.caption2)
                .foregroundStyle(Theme.ink.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .overlay { if working { ProgressView().tint(Theme.coral) } }
        .onAppear { bounce = true }
        .alert("안내", isPresented: Binding(
            get: { auth.errorMessage != nil },
            set: { if !$0 { auth.errorMessage = nil } }
        )) { Button("확인", role: .cancel) {} } message: { Text(auth.errorMessage ?? "") }
    }
}
