import AppKit
import ApprovalCore
import Darwin
import WebKit

@MainActor
final class ApprovalApplication: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate {
    private let input: FileHandle
    private let options: Options
    private let terminate: (Int32) -> Void
    private let profileDirectory: URL?
    private let makeWebView: (WKWebViewConfiguration) -> WKWebView
    private var stream = AuthenticationStream()
    private var inputLine = Data()
    private var request: ApprovalRequest?
    private var window: NSWindow?
    private var webView: WKWebView?
    private var timer: Timer?
    private var deadline: Timer?
    private var evaluating = false
    private var finished = false
    private var startedAt = Date()
    private var profileLock: Int32 = -1

    init(options: Options, input: FileHandle = .standardInput, profileDirectory: URL? = nil,
         makeWebView: @escaping (WKWebViewConfiguration) -> WKWebView = {
             WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 720), configuration: $0)
         }, terminate: @escaping (Int32) -> Void = { exit($0) }) {
        self.options = options
        self.input = input
        self.profileDirectory = profileDirectory
        self.makeWebView = makeWebView
        self.terminate = terminate
        super.init()
    }

    func applicationDidFinishLaunching(_ _: Notification) {
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
        input.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil }
            Task { @MainActor [weak self] in self?.consumeInput(data) }
        }
    }

    private func consumeInput(_ data: Data) {
        guard !finished else { return }
        do {
            for byte in data {
                inputLine.append(byte)
                guard inputLine.count <= 65_536 else { throw ApprovalError.inputTooLarge }
                if byte == 10 {
                    try stream.append(String(decoding: inputLine, as: UTF8.self))
                    inputLine.removeAll(keepingCapacity: true)
                    try applyStreamRequest()
                }
            }
            if data.isEmpty {
                try stream.append(String(decoding: inputLine, as: UTF8.self))
                stream.finish()
                try applyStreamRequest()
                if request == nil { finish(1, message: "No supported AWS authorisation URL was received.") }
            }
        } catch {
            finish(1, message: "Could not read authentication input.")
        }
    }

    private func applyStreamRequest() throws {
        guard let next = try stream.request() else { return }
        if let request, next.url != request.url {
            finish(1, message: "Multiple requests received. Use one helper per authentication request.")
        } else if request == nil {
            start(next)
        } else if next.code != nil {
            request = next
        }
    }

    private func acquireProfile() throws {
        let root = try profileDirectory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
            .appendingPathComponent("AWSAutoApprove", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        profileLock = open(root.appendingPathComponent("session.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard profileLock >= 0, flock(profileLock, LOCK_EX | LOCK_NB) == 0 else {
            throw CocoaError(.fileLocking)
        }
    }

    func start(_ request: ApprovalRequest) {
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
        let view = makeWebView(configuration)
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

    func inspectPage() {
        guard !finished, !evaluating, let view = webView, !view.isLoading, let request else { return }
        guard request.allowsAutomation(at: view.url) else {
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
                case "clicked": FileHandle.standardError.write(Data("Submitted AWS approval step.\n".utf8))
                case "waiting": break
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

    func webView(_ _: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        // Identity-provider redirects are displayed, but only the initiating AWS page gets automation.
        let scheme = navigationAction.request.url?.scheme
        decisionHandler(scheme == "https" || scheme == "about" ? .allow : .cancel)
    }

    func webView(_ _: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
        finish(1, message: "The sign-in page could not load. Check connectivity and retry.")
    }

    func webViewWebContentProcessDidTerminate(_ _: WKWebView) {
        finish(1, message: "The sign-in web process stopped. Retry authentication.")
    }

    func windowWillClose(_ _: Notification) {
        finish(2, message: "Authentication cancelled.")
    }

    func applicationShouldTerminate(_ _: NSApplication) -> NSApplication.TerminateReply {
        finish(2, message: "Authentication cancelled.")
        return .terminateCancel
    }

    func finish(_ status: Int32, message: String) {
        guard !finished else { return }
        finished = true
        timer?.invalidate()
        deadline?.invalidate()
        input.readabilityHandler = nil
        webView?.stopLoading()
        if profileLock >= 0 { close(profileLock) }
        FileHandle.standardError.write(Data((message + "\n").utf8))
        terminate(status)
    }
}
