import SwiftUI
import UIKit

/// Temporarily disables UINavigationController interactive-pop (back swipe) while a specific gesture is in progress.
///
/// This prevents accidental navigation pop when we use horizontal swipes inside a NavigationStack.
struct InteractivePopGestureDisabler: UIViewControllerRepresentable {
    let disabled: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            uiViewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = !disabled
        }
    }
}
