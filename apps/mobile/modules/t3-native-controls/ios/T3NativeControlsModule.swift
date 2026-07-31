import ExpoModulesCore
import Security
import UIKit

public final class T3NativeControlsModule: Module {
  public func definition() -> ModuleDefinition {
    Name("T3NativeControls")

    Function("getShowcasePairingUrl") {
      let arguments = ProcessInfo.processInfo.arguments
      guard
        let flagIndex = arguments.firstIndex(of: "--showcasePairingUrl"),
        arguments.indices.contains(flagIndex + 1)
      else {
        return nil as String?
      }
      return arguments[flagIndex + 1]
    }

    Function("getShowcaseScene") { () -> String? in
      let scenePath = NSHomeDirectory() + "/Library/Caches/T3ShowcaseScene"
      if let storedScene = try? String(contentsOfFile: scenePath, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines), !storedScene.isEmpty {
        return storedScene
      }
      let arguments = ProcessInfo.processInfo.arguments
      guard
        let flagIndex = arguments.firstIndex(of: "--showcaseScene"),
        arguments.indices.contains(flagIndex + 1)
      else {
        return nil as String?
      }
      return arguments[flagIndex + 1]
    }

    Function("getShowcaseOrientation") { () -> String? in
      let arguments = ProcessInfo.processInfo.arguments
      guard
        let flagIndex = arguments.firstIndex(of: "--showcaseOrientation"),
        arguments.indices.contains(flagIndex + 1)
      else {
        return nil as String?
      }
      return arguments[flagIndex + 1]
    }

    // Rotates the interface without Simulator menu UI scripting, which CI
    // runners cannot perform (osascript is denied Accessibility access there).
    AsyncFunction("applyShowcaseOrientation") { (orientation: String) in
      guard #available(iOS 16.0, *) else { return }
      let mask: UIInterfaceOrientationMask = orientation == "landscape" ? .landscapeRight : .portrait
      for case let windowScene as UIWindowScene in UIApplication.shared.connectedScenes {
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
          NSLog("T3NativeControls applyShowcaseOrientation(\(orientation)) failed: \(error)")
        }
        for window in windowScene.windows {
          window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
      }
    }.runOnQueue(.main)

    // The geometry request above can fail transiently (for example before the
    // scene is foreground-active), so callers poll this until it settles.
    AsyncFunction("getInterfaceOrientation") { () -> String in
      guard #available(iOS 16.0, *),
        let windowScene = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .first
      else {
        return "unknown"
      }
      return windowScene.effectiveGeometry.interfaceOrientation.isLandscape
        ? "landscape"
        : "portrait"
    }.runOnQueue(.main)

    Function("prepareShowcaseCapture") {
      for itemClass in [kSecClassGenericPassword, kSecClassInternetPassword] {
        SecItemDelete([kSecClass as String: itemClass] as CFDictionary)
      }
    }

    Function("markShowcaseReady") { (scene: String) in
      let readyPath = NSHomeDirectory() + "/Library/Caches/T3ShowcaseReadyScene"
      try? scene.write(toFile: readyPath, atomically: true, encoding: .utf8)
    }

    View(T3HeaderButtonView.self) {
      Prop("label") { (view: T3HeaderButtonView, label: String) in
        view.setLabel(label)
      }
      Prop("systemImage") { (view: T3HeaderButtonView, systemImage: String) in
        view.setSystemImage(systemImage)
      }

      Events("onTriggered")
    }
  }
}
