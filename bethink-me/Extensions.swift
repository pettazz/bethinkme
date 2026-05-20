import Foundation
import SwiftUI


struct RuntimeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

extension Color {
    // via https://blog.eidinger.info/from-hex-to-color-and-back-in-swiftui
    // made slightly dumber by me
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0

        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, opacity: 1.0)
    }
    
    func toHex() -> String {
        let uic = UIColor(self)
        let components = uic.cgColor.components!
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
