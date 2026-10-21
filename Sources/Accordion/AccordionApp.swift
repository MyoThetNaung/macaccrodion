import AppKit
import SwiftUI

@main
enum AccordionMain {
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            let failures = AccordionSelfTest.run()
            exit(failures == 0 ? 0 : 1)
        }
        AccordionApp.main()
    }
}

@MainActor
final class AccordionDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let logoURL = Bundle.main.url(forResource: "AppLogo", withExtension: "png")
            ?? Bundle.module.url(forResource: "AppLogo", withExtension: "png")
        if let logoURL, let image = NSImage(contentsOf: logoURL) {
            NSApp.applicationIconImage = image
        }
        NSApp.activate()
        showWindows()
        DispatchQueue.main.async {
            self.showWindows()
        }
    }

    private func showWindows() {
        for window in NSApp.windows {
            window.sharingType = .readOnly
            window.makeKeyAndOrderFront(nil)
        }
        fputs("windows \(NSApp.windows.count)\n", stderr)
    }
}

struct AccordionApp: App {
    @NSApplicationDelegateAdaptor(AccordionDelegate.self) private var delegate
    @StateObject private var model = AccordionModel()

    var body: some Scene {
        WindowGroup("Accordion") {
            ContentView(model: model)
                .onAppear { model.start() }
        }
        .defaultSize(width: 960, height: 820)
    }
}
