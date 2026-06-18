import SwiftUI

/// 브랜드 로더 — 라임 점 3개가 통통 튄다.
struct CatchLoader: View {
    var size: CGFloat = 9
    var color: Color = Theme.lime
    @State private var bouncing = false

    var body: some View {
        HStack(spacing: size * 0.7) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .offset(y: bouncing ? -size * 0.7 : size * 0.7)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.13),
                        value: bouncing
                    )
            }
        }
        .onAppear { bouncing = true }
    }
}
