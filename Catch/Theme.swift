import SwiftUI
import UIKit

/// 뽀짝 디자인 토큰 — 파스텔 + 라운드.
enum Theme {
    static let ink     = Color(hex: 0x3A2E3F)   // 따뜻한 먹색
    static let cream   = Color(hex: 0xFFF7F2)
    static let coral   = Color(hex: 0xFF7A90)    // 메인 액센트(딸기)
    static let grape   = Color(hex: 0xB18CFF)    // 보조(라일락)
    static let mint    = Color(hex: 0x57E0BE)
    static let butter  = Color(hex: 0xFFD36B)

    static let bgTop    = Color(hex: 0xFFE6EE)   // 코튼캔디
    static let bgBottom = Color(hex: 0xE9E2FF)   // 소프트 라일락

    static var background: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
    }

    // SpriteKit 씬 배경 그라데이션용 UIColor
    static let sceneTop = UIColor(hex: 0xFFE6EE)
    static let sceneBottom = UIColor(hex: 0xE3DBFF)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: UInt) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// 통통한 알약 버튼.
struct CuteButtonStyle: ButtonStyle {
    var bg: Color = Theme.coral
    var fg: Color = .white
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(bg, in: Capsule())
            .shadow(color: bg.opacity(0.45), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 떠다니는 둥근 아이콘 버튼.
struct CuteIconButtonStyle: ButtonStyle {
    var bg: Color = .white
    var fg: Color = Theme.ink
    var size: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(fg)
            .frame(width: size, height: size)
            .background(bg, in: Circle())
            .shadow(color: Theme.ink.opacity(0.18), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
