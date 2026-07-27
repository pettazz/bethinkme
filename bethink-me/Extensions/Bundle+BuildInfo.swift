import Foundation


extension Bundle {
    // ty https://stackoverflow.com/a/68912269/431223
    // swiftlint:disable all
    public var appName: String           { getInfo("CFBundleName") }
    public var displayName: String       { getInfo("CFBundleDisplayName") }
    public var language: String          { getInfo("CFBundleDevelopmentRegion") }
    public var identifier: String        { getInfo("CFBundleIdentifier") }
    public var copyright: String         { getInfo("NSHumanReadableCopyright").replacingOccurrences(of: "\\\\n", with: "\n") }

    public var appBuild: String          { getInfo("CFBundleVersion") }
    public var appVersionLong: String    { getInfo("CFBundleShortVersionString") }
    //public var appVersionShort: String { getInfo("CFBundleShortVersion") }

    public var appGitReleaseVersion: String { getInfo("GitReleaseVersion") }

    fileprivate func getInfo(_ str: String) -> String { infoDictionary?[str] as? String ?? "⚠️" }
    // swiftlint:enable all

    private static var isTestFlight: Bool {
        guard !isDebug else { return false }
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    private static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static var env: Env {
        if isDebug {
            return .debug
        } else if isTestFlight {
            return .testFlight
        } else {
            return .appStore
        }
    }
}
