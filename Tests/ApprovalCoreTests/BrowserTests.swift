import AppKit
import WebKit
import XCTest
@testable import ApprovalCore

@MainActor
final class BrowserTests: XCTestCase {
    private var view: WKWebView!

    private func needsInteraction(html: String) async throws -> Bool {
        _ = NSApplication.shared
        view = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let source = """
        document.body.innerHTML = html;
        document.querySelectorAll('input[type="password"]').forEach(input => {
            Object.defineProperty(input, 'value', {get: () => {throw new Error('Credential value was read');}});
        });
        \(InteractionPrompt.scriptSource)
        """
        let result = try await view.callAsyncJavaScript(source, arguments: ["html": html],
                                                        in: nil, contentWorld: .page)
        return try XCTUnwrap(result as? Bool)
    }

    func testPassiveInspectionWaitsForCredentialsOrManualControls() async throws {
        for html in ["<input type='password' role='button'>", "<input type='email'>", "<input type='radio' name='mfa'>",
                     "<button>Use another account</button>", "<input inputmode='numeric' autocomplete='one-time-code'>",
                     "<iframe src='https://mfa.example.invalid/frame' width='400' height='300'></iframe>"] {
            let needed = try await needsInteraction(html: html)
            XCTAssertTrue(needed, html)
        }
    }

    func testPassiveInspectionIgnoresAutomaticProgressAndHiddenControls() async throws {
        for html in ["<p>Signing you in...</p><button>Cancel</button>", "<input type='hidden'>",
                     "<input type='password' style='display:none'>", "<button disabled>Continue</button>",
                     "<input readonly><button aria-disabled='true'>Next</button>",
                     "<input type='checkbox'>Remember this device", "<iframe style='display:none'></iframe>",
                     "<input type='password' style='visibility:collapse'>",
                     "<div style='opacity:0'><input type='password'></div>",
                     "<fieldset disabled><input type='password'></fieldset>",
                     "<input type='password' style='position:absolute;left:-10000px'>",
                     "<iframe src='https://sso.example.invalid/silent' width='400' height='300' style='position:absolute;left:-10000px'></iframe>",
                     "<input type='password'><div style='position:fixed;inset:0;background:white'>Signing in...</div>"] {
            let needed = try await needsInteraction(html: html)
            XCTAssertFalse(needed, html)
        }
    }

    private func evaluate(html: String, code: String = "", host: String = "eu-west-1.signin.aws",
                          repeated: Bool = false) async throws -> String {
        _ = NSApplication.shared
        view = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        // Fixture origin is supplied explicitly; production always uses the real page location.
        let settings: [String: Any] = ["expectedCode": code, "host": "eu-west-1.signin.aws", "paths": ["/platform/authorize"]]
        let script = """
        document.body.innerHTML = html;
        window.clicks = 0;
        document.querySelectorAll('button,input').forEach(b => b.onclick = () => window.clicks++);
        function inspect(document, location, settings) {
        \(ApprovalRequest.automationSource)
        }
        const state = inspect(document, {pathname:'/platform/authorize',protocol:'https:',hostname:host}, settings);
        \(repeated ? "inspect(document, {pathname:'/platform/authorize',protocol:'https:',hostname:host}, settings);" : "")
        return state + ':' + window.clicks;
        """
        // A blank WKWebView has a document immediately and executes the real WebKit DOM code.
        return try await withCheckedThrowingContinuation { continuation in
            view.callAsyncJavaScript(script, arguments: ["html": html, "host": host, "settings": settings],
                                     in: nil, in: .page) { outcome in
                continuation.resume(with: outcome.map { $0 as? String ?? "invalid" })
            }
        }
    }

    func testAllowClicksOnce() async throws {
        let result = try await evaluate(html: "<p>AWS requests access</p><button>Allow</button>", repeated: true)
        XCTAssertEqual(result, "clicked:1")
    }

    func testJavaScriptInAnArgumentRemainsData() async throws {
        let result = try await evaluate(html: "<p>AWS ABCD-1234</p><button>Confirm</button>",
                                        code: "'; window.clicks = 99; //")
        XCTAssertEqual(result, "mismatch:0")
    }

    func testCodeMatchAndMismatch() async throws {
        let html = "<p>AWS ABCD-1234</p><button>Confirm</button>"
        let matched = try await evaluate(html: html, code: "ABCD-1234")
        XCTAssertEqual(matched, "clicked:1")
        let mismatch = try await evaluate(html: html, code: "WXYZ-5678")
        XCTAssertEqual(mismatch, "mismatch:0")
        let missing = try await evaluate(html: html)
        XCTAssertEqual(missing, "interactive:0")
    }

    func testRejectsWrongOriginAmbiguousDisabledAndHiddenButtons() async throws {
        let html = "<p>AWS access</p><button>Allow</button>"
        let origin = try await evaluate(html: html, host: "evil.test")
        XCTAssertEqual(origin, "interactive:0")
        for buttons in ["<button>Allow</button><button>Allow</button>", "<button disabled>Allow</button>",
                        "<button style='display:none'>Allow</button>", "<button aria-disabled='true'>Allow</button>"] {
            let result = try await evaluate(html: "<p>AWS access</p>" + buttons)
            XCTAssertEqual(result, "interactive:0")
        }
    }

    func testSuccessAndUnrecognisedPage() async throws {
        let success = try await evaluate(html: "<p>You can now close this window</p>")
        XCTAssertEqual(success, "complete:0")
        let login = try await evaluate(html: "<input type='password'><button>Sign in</button>")
        XCTAssertEqual(login, "interactive:0")
        let other = try await evaluate(html: "<p>Unrelated access</p><button>Allow</button>")
        XCTAssertEqual(other, "interactive:0")
    }
}
