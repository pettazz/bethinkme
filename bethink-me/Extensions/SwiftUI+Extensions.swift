import SwiftUI


extension Color {
    // via https://blog.eidinger.info/from-hex-to-color-and-back-in-swiftui
    // made slightly dumber by me
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        // swiftlint:disable identifier_name
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        // swiftlint:enable identifier_name
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, opacity: 1.0)
    }

    func toHex() -> String {
        let uic = UIColor(self)
        // swiftlint:disable identifier_name
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        // swiftlint:enable identifier_name
        uic.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "%02lX%02lX%02lX",
            lroundf(Float(r) * 255),
            lroundf(Float(g) * 255),
            lroundf(Float(b) * 255)
        )
    }
}

extension UIViewController {
    var topmostPresentedViewController: UIViewController? {
        presentedViewController?.topmostPresentedViewController ?? self
    }
}
