import SwiftUI

// adapted from https://github.com/fatbobman/SheetKit/tree/main
protocol ModalSheet {
    var keyWindow: UIWindow? { get }
    var rootViewController: UIViewController? { get }

    func present(_ contentView: some View)
    func dismiss()
}

extension ModalSheet {
    var keyWindow: UIWindow? { UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { $0 as? UIWindowScene }
            .compactMap { $0 }
            .first?.windows
            .first(where: { $0.isKeyWindow })
    }

    var rootViewController: UIViewController? { keyWindow?.rootViewController }


    func present(_ contentView: some View) {
        let viewController = rootViewController?.topmostPresentedViewController
        let contentViewController = UIHostingController(rootView: contentView)
        viewController?.present(contentViewController, animated: true)
    }

    func dismiss() {
        rootViewController?.dismiss(animated: true)
    }
}
