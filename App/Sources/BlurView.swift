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
    /// Translucent blurred nav/tab bars that the content shows through.
    /// Set once at launch: SwiftUI's toolbarBackground(_:for:) only took a
    /// ShapeStyle, and the material it produced read as a solid colour.
    static func applyTranslucent() {
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()          // system blur, not a fill
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
