import SwiftUI

// Colour values read out of Telegram-iOS's own theme sources
// (DefaultDay/DefaultDarkPresentationTheme.swift) so the screens match the
// reference exactly instead of being eyeballed. Values only — no code copied,
// since that project is GPL and this one isn't.
enum TG {
    private static func dyn(_ light: UInt32, _ dark: UInt32,
                            lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(rgb: dark, alpha: darkAlpha)
            : UIColor(rgb: light, alpha: lightAlpha) })
    }

    static let accent = Color(UIColor(rgb: 0x0088ff))

    // Chat list
    static let listBackground = dyn(0xffffff, 0x000000)
    static let separator      = dyn(0xc8c7cc, 0x545458, darkAlpha: 0.55)
    static let title          = dyn(0x000000, 0xffffff)
    static let dateText       = dyn(0x8e8e93, 0x8d8e93)
    static let messageText    = dyn(0x8e8e93, 0x8d8e93)
    static let muteIcon       = dyn(0xa7a7ad, 0x8d8e93)
    static let badgeActive    = accent
    static let badgeInactive  = dyn(0xb6b6bb, 0x48484c)
    static let pinnedBadge    = dyn(0xb6b6bb, 0x48484c)
    static let searchBar      = dyn(0xe9e9e9, 0x1c1c1d)
    static let onlineDot      = Color(UIColor(rgb: 0x4cc91f))

    // Bubbles: light is the classic white/green pair, dark the blue gradient.
    static let incomingBubble = dyn(0xffffff, 0x1d1d1d)
    static let incomingText   = dyn(0x000000, 0xffffff)
    static var outgoingFill: [Color] {
        [Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(rgb: 0x61BCF9) : UIColor(rgb: 0xe1ffc7) }),
         Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(rgb: 0x0088ff) : UIColor(rgb: 0xe1ffc7) })]
    }
    static let outgoingText   = dyn(0x000000, 0xffffff)
}

extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255,
                  green: CGFloat((rgb >> 8) & 0xff) / 255,
                  blue: CGFloat(rgb & 0xff) / 255,
                  alpha: alpha)
    }
}
