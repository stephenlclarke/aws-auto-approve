import AppKit
import WebKit
import XCTest
@testable import ApprovalCore
@testable import AWSAutoApprove

@MainActor
private final class TestWebView: WKWebView {
    var address: URL?
    var state: String? = "interactive"
    var scriptError: Error?
    var stopped = false
    var scripts = 0
    var onLoad: (() -> Void)?
    override var url: URL? { address }
    override var isLoading: Bool { false }
    override func load(_ request: URLRequest) -> WKNavigation? {
        address = request.url
        onLoad?()
        return nil // Isolate network requests; DOM actions have separate native WebKit tests.
    }
    override func stopLoading() { stopped = true }
    override func evaluateJavaScript(_ javaScriptString: String,
                                    completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil) {
        scripts += 1
        completionHandler?(state, scriptError)
    }
}

@MainActor
final class ApplicationTests: XCTestCase {
    private let address = "https://eu-west-1.signin.aws/platform/authorize?request_uri=fixture"

    private func exercise(_ body: (ApprovalApplication, TestWebView, () -> [Int32]) throws -> Void) throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let view = TestWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        var statuses: [Int32] = []
        let options = try Options(arguments: ["--visible", address])
        let app = ApprovalApplication(options: options, profileDirectory: root,
                                      makeWebView: { _ in view }, terminate: { statuses.append($0) })
        defer { app.finish(2, message: "Fixture cleanup.") }
        app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        try body(app, view, { statuses })
    }

    func testCompletionClosesAndStopsOnce() throws {
        try exercise { app, view, statuses in
            view.state = "complete"
            app.inspectPage()
            app.inspectPage()
            XCTAssertEqual(statuses(), [0])
            XCTAssertTrue(view.stopped)
            XCTAssertEqual(view.scripts, 1)
        }
    }

    func testMismatchAndCancellation() throws {
        try exercise { app, view, statuses in
            view.state = "mismatch"
            app.inspectPage()
            XCTAssertEqual(statuses(), [1])
        }
        try exercise { app, _, statuses in
            app.windowWillClose(Notification(name: NSWindow.willCloseNotification))
            XCTAssertEqual(statuses(), [2])
        }
        try exercise { app, _, statuses in
            XCTAssertEqual(app.applicationShouldTerminate(NSApp), .terminateCancel)
            XCTAssertEqual(statuses(), [2])
        }
    }

    func testPendingInteractiveAndScriptFailureDoNotApprove() throws {
        try exercise { app, view, statuses in
            for state in ["clicked", "waiting", "interactive"] {
                view.state = state
                app.inspectPage()
                XCTAssertTrue(statuses().isEmpty)
            }
            view.scriptError = CocoaError(.coderInvalidValue)
            app.inspectPage()
            XCTAssertTrue(statuses().isEmpty)
        }
    }

    func testRedirectsNeverReceiveAutomation() throws {
        try exercise { app, view, statuses in
            for address in ["https://login.microsoftonline.com/", "http://eu-west-1.signin.aws/platform/authorize",
                            "https://eu-west-1.signin.aws/settings"] {
                view.address = URL(string: address)
                app.inspectPage()
            }
            XCTAssertEqual(view.scripts, 0)
            XCTAssertTrue(statuses().isEmpty)
        }
    }

    func testNavigationFailuresReturnFailure() throws {
        try exercise { app, view, statuses in
            app.webView(view, didFailProvisionalNavigation: nil, withError: CocoaError(.fileReadUnknown))
            XCTAssertEqual(statuses(), [1])
        }
        try exercise { app, view, statuses in
            app.webViewWebContentProcessDidTerminate(view)
            XCTAssertEqual(statuses(), [1])
        }
    }

    func testLiveStreamEOFInvalidInputAndMultipleRequests() async throws {
        for content in [address + "\n[i] Code: ABCD-1234\n", address,
                        "ordinary output\n", address + "\n" + address + "2\n",
                        String(repeating: "x", count: 65_537)] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let pipe = Pipe()
            let view = TestWebView(frame: .zero)
            var statuses: [Int32] = []
            let completed = XCTestExpectation(description: "Input reached its expected result")
            let valid = content == address || content.hasSuffix("ABCD-1234\n")
            if valid { view.onLoad = { completed.fulfill() } }
            let app = ApprovalApplication(options: try Options(arguments: ["--stdin"]),
                                          input: pipe.fileHandleForReading, profileDirectory: root,
                                          makeWebView: { _ in view }, terminate: {
                                              statuses.append($0)
                                              if !valid { completed.fulfill() }
                                          })
            app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            // Writing on another task prevents a full pipe from blocking the AppKit run loop.
            let writer = Task.detached {
                try pipe.fileHandleForWriting.write(contentsOf: Data(content.utf8))
                try pipe.fileHandleForWriting.close()
            }
            try await writer.value
            let result = await XCTWaiter.fulfillment(of: [completed], timeout: 10)
            XCTAssertEqual(result, .completed)
            if valid {
                XCTAssertNotNil(view.address)
                view.state = "complete"
                app.inspectPage()
                XCTAssertEqual(statuses, [0])
            } else {
                XCTAssertEqual(statuses, [1])
            }
            app.finish(2, message: "Fixture cleanup.")
        }
    }

    func testStreamStartsBeforeTheWriterCloses() async throws {
        _ = NSApplication.shared
        let pipe = Pipe()
        let view = TestWebView(frame: .zero)
        let loaded = XCTestExpectation(description: "Live URL loads before EOF")
        view.onLoad = { loaded.fulfill() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = ApprovalApplication(options: try Options(arguments: ["--stdin"]),
                                      input: pipe.fileHandleForReading, profileDirectory: root,
                                      makeWebView: { _ in view }, terminate: { _ in })
        app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        try pipe.fileHandleForWriting.write(contentsOf: Data((address + "\n").utf8))
        let result = await XCTWaiter.fulfillment(of: [loaded], timeout: 3)
        try pipe.fileHandleForWriting.close()
        XCTAssertEqual(result, .completed)
        app.finish(2, message: "Fixture cleanup.")
    }

    func testDeadlineReturnsFailure() async throws {
        let pipe = Pipe()
        var statuses: [Int32] = []
        let completed = XCTestExpectation(description: "Deadline expired")
        let app = ApprovalApplication(options: try Options(arguments: ["--stdin", "--timeout", "1"]),
                                      input: pipe.fileHandleForReading, terminate: {
                                          statuses.append($0)
                                          completed.fulfill()
                                      })
        app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        let result = await XCTWaiter.fulfillment(of: [completed], timeout: 10)
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(statuses, [1])
        try pipe.fileHandleForWriting.close()
    }

    func testUnknownAWSPageBecomesVisible() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let view = TestWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let app = ApprovalApplication(options: try Options(arguments: [address]), profileDirectory: root,
                                      makeWebView: { _ in view }, terminate: { _ in })
        app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        XCTAssertFalse(view.window?.isVisible ?? true)
        let deadline = ContinuousClock.now + .seconds(10)
        while !(view.window?.isVisible ?? false) && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(view.window?.isVisible ?? false)
        app.finish(2, message: "Fixture cleanup.")
    }

    func testSessionLockRejectsConcurrentApproval() throws {
        try exercise { app, _, statuses in
            app.start(try ApprovalRequest(url: address))
            XCTAssertEqual(statuses(), [1])
        }
    }
}
