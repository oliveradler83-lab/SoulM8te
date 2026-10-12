import SwiftUI

enum Theme {
    static let top = Color(hex: 0x0C1221)
    static let mid = Color(hex: 0x021A66)
    static let bottom = Color(hex: 0x001C9E)
    static let accent = Color(hex: 0x4FC3F7)
    static let pill = Color(hex: 0x0A2A9E)

    static var background: some View {
        LinearGradient(
            stops: [
                .init(color: top, location: 0.0),
                .init(color: mid, location: 0.65),
                .init(color: bottom, location: 1.0)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    static func font(_ size: CGFloat, _ weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let logoTracking: CGFloat = 9
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
