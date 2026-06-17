import SwiftUI

/// 최초 로그인 시 username 설정. 형식·중복·예약어를 실시간 확인.
struct OnboardingUsernameView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var username = ""
    @State private var status: Status = .idle
    @State private var saving = false
    @State private var checkTask: Task<Void, Never>?

    enum Status: Equatable { case idle, checking, available, taken, invalid }

    private var normalized: String { username.lowercased() }
    private var formatValid: Bool { normalized.range(of: "^[a-z0-9_]{2,20}$", options: .regularExpression) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("이름을 정해요 🐣")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("영문 소문자·숫자·밑줄(_) 2~20자")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink.opacity(0.5))

            HStack(spacing: 6) {
                Text("@").foregroundStyle(Theme.coral).fontWeight(.bold)
                TextField("", text: $username, prompt: Text("username").foregroundColor(Theme.ink.opacity(0.3)))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.ink)
                    .onChange(of: username) { _, _ in scheduleCheck() }
                statusIcon
            }
            .padding(.horizontal, 18).frame(height: 56)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(borderColor, lineWidth: 2))

            statusText

            Spacer()

            Button {
                saving = true
                Task { _ = await auth.setUsername(normalized); saving = false }
            } label: {
                Text(saving ? "만드는 중…" : "시작하기")
            }
            .buttonStyle(CuteButtonStyle(bg: canSubmit ? Theme.coral : Theme.ink.opacity(0.2)))
            .disabled(!canSubmit || saving)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background.ignoresSafeArea())
    }

    private var canSubmit: Bool { status == .available && !saving }

    private var borderColor: Color {
        switch status {
        case .available: return Theme.mint
        case .taken, .invalid: return Theme.coral
        default: return .clear
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch status {
        case .checking: ProgressView().tint(Theme.coral)
        case .available: Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mint)
        case .taken, .invalid: Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.coral)
        case .idle: EmptyView()
        }
    }

    @ViewBuilder private var statusText: some View {
        switch status {
        case .invalid: Text("형식이 올바르지 않아요").foregroundStyle(Theme.coral).font(.caption.weight(.medium))
        case .taken: Text("이미 사용 중이에요 🥲").foregroundStyle(Theme.coral).font(.caption.weight(.medium))
        case .available: Text("사용할 수 있어요! 🎉").foregroundStyle(Theme.mint).font(.caption.weight(.bold))
        default: EmptyView()
        }
    }

    private func scheduleCheck() {
        checkTask?.cancel()
        guard !username.isEmpty else { status = .idle; return }
        guard formatValid else { status = .invalid; return }
        status = .checking
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            let ok = await auth.isUsernameAvailable(normalized)
            if Task.isCancelled { return }
            status = ok ? .available : .taken
        }
    }
}
