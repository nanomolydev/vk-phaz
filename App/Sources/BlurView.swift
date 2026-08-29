import SwiftUI
import UIKit

// UIVisualEffectView, not SwiftUI's Material. The material kept rendering as a
// flat slab over the chat wallpaper; UIKit's blur samples the real backdrop and
// is not subject to SwiftUI's compositing rules.
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemUltraThinMaterial

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        view.effect = UIBlurEffect(style: style)
    }
}

enum BarAppearance {
    /// Fully transparent nav/tab bars, so the chat and the wallpaper show
    /// through and only the floating glass controls sit on top. A bar
    /// *background* — however thin — reads as a solid strip against a
    /// wallpaper; the reference design has no strip at all.
    static func applyTranslucent() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
