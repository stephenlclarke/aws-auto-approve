import AppKit
import ApprovalCore
import Darwin
import WebKit

@MainActor
final class ApprovalApplication: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate {
    private let options: Options
    private var request: ApprovalRequest?
    private var window: NSWindow?
    private var webView: WKWebView?
    private var timer: Timer?
    private var deadline: Timer?
    private var evaluating = false
    private var finished = false
    private var startedAt = Date()
    private var profileLock: Int32 = -1

    init(options: Options) {
        self.options = options
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let menu = NSMenu()
        let item = NSMenuItem()
        menu.addItem(item)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit AWS Auto Approve", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu
        NSApp.mainMenu = menu
        deadline = Timer.scheduledTimer(withTimeInterval: options.timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finish(1, message: "Authentication timed out. Retry the initiating command.") }
        }
        if let request = options.request {
            start(request)
        } else {
            readAuthenticationInput()
        }
    }

    private func readAuthenticationInput() {
        Task { @MainActor in
            var stream = AuthenticationStream()
            do {
                // Async input leaves AppKit's main run loop free while the CLI awaits approval.
                for try await line in FileHandle.standardInput.bytes.lines {
                    try stream.append(line + "\n")
                    if let next = try stream.request() {
                        if let request, next.url != request.url {
                            finish(1, message: "Multiple requests received. Use one helper per authentication request.")
                            return
                        }
                        if request == nil { start(next) }
                        else if next.code != nil { request = next }
                    }
                }
                stream.finish()
                if request == nil {
                    if let next = try stream.request() { start(next) }
                    else { finish(1, message: "No supported AWS authorisation URL was received.") }
                }
            } catch {
                finish(1, message: "Could not read authentication input.")
            }
        }
    }

    private func acquireProfile() throws {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
            .appendingPathComponent("AWSAutoApprove", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        profileLock = open(root.appendingPathComponent("session.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard profileLock >= 0, flock(profileLock, LOCK_EX | LOCK_NB) == 0 else {
            throw CocoaError(.fileLocking)
        }
    }

    private func start(_ request: ApprovalRequest) {
        guard !finished else { return }
        do { try acquireProfile() }
        catch {
            finish(1, message: "Another approval is active, or the session cannot be locked. Retry after it finishes.")
            return
        }
        self.request = request
        startedAt = Date()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 720), configuration: configuration)
        view.navigationDelegate = self
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "AWS Auto Approve - sign in if required"
        window.contentView = view
        window.delegate = self
        window.center()
        self.window = window
        webView = view
        view.load(URLRequest(url: request.url))
        if options.visible { showWindow() }
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.inspectPage() }
        }
    }

    private func inspectPage() {
        guard !finished, !evaluating, let view = webView, !view.isLoading, let request else { return }
        guard view.url?.scheme == "https", view.url?.host == request.url.host,
              view.url?.path == request.url.path else {
            showWindow()
            return
        }
        evaluating = true
        do {
            view.evaluateJavaScript(try request.script()) { [weak self] result, error in
                guard let self, !self.finished else { return }
                self.evaluating = false
                if error != nil { self.showWindow(); return }
                switch result as? String {
                case "complete": self.finish(0, message: "AWS approval completed.")
                case "mismatch": self.finish(1, message: "Confirmation code mismatch. No approval was made.")
                case "clicked", "waiting": break
                default:
                    if Date().timeIntervalSince(self.startedAt) > 2 { self.showWindow() }
                }
            }
        } catch {
            evaluating = false
            finish(1, message: "Could not prepare the approval page check.")
        }
    }

    private func showWindow() {
        guard let window, !window.isVisible else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        // Identity-provider redirects are displayed, but only the initiating AWS page gets automation.
        let scheme = navigationAction.request.url?.scheme
        decisionHandler(scheme == "https" || scheme == "about" ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(1, message: "The sign-in page could not load. Check connectivity and retry.")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish(1, message: "The sign-in web process stopped. Retry authentication.")
    }

    func windowWillClose(_ notification: Notification) {
        finish(2, message: "Authentication cancelled.")
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        finish(2, message: "Authentication cancelled.")
        return .terminateCancel
    }

    private func finish(_ status: Int32, message: String) {
        guard !finished else { return }
        finished = true
        timer?.invalidate()
        deadline?.invalidate()
        webView?.stopLoading()
        if profileLock >= 0 { close(profileLock) }
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(status)
    }
}
