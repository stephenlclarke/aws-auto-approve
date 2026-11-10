# AWS Auto Approve

<p align="center">
  <a href="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/ci.yml"><img alt="CI on main" src="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/ci.yml/badge.svg" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/unit-tests.yml"><img alt="Unit tests on main" src="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/unit-tests.yml/badge.svg" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/dependency-review.yml"><img alt="Dependency Review" src="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/dependency-review.yml/badge.svg" /></a>
  <a href=".github/dependabot.yml"><img alt="Dependabot: daily updates" src="https://img.shields.io/badge/Dependabot-daily_updates-blue.svg" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/security"><img alt="GitHub security" src="https://img.shields.io/badge/Security-GitHub-blue.svg" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/releases"><img alt="Source preview" src="https://img.shields.io/badge/Release-source_preview-orange.svg" /></a>
  <a href="#install"><img alt="Homebrew source installation" src="https://img.shields.io/badge/Homebrew-install-blue.svg" /></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-blue.svg" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Quality Gate Status" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=alert_status" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Bugs" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=bugs" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Code Smells" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=code_smells" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Coverage" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=coverage" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Duplicated Lines (%)" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=duplicated_lines_density" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Lines of Code" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=ncloc" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Reliability Rating" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=reliability_rating" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Security Rating" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=security_rating" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Technical Debt" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=sqale_index" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Maintainability Rating" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=sqale_rating" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Vulnerabilities" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=vulnerabilities" /></a>
  <img alt="Repo Visitors" src="https://visitor-badge.laobi.icu/badge?page_id=stephenlclarke.aws-auto-approve" />
</p>

Native Swift helper that opens a locally initiated AWS SSO request, clicks **Allow**, and closes after the approval page confirms completion. It uses macOS WebKit. No third-party apps, libraries, browser extensions or external browser are required at runtime.

**Initial source preview:** the native browser fixtures and input checks are automated. A successful live AWS/identity-provider login must be verified in your environment before relying on unattended use. Release and Homebrew badges describe the current source installation, not a signed downloadable release or published tap cask.

## Requirements

macOS 14 or later. Building needs Xcode with Swift 6 or later. The Makefile selects Xcode's bundled compiler to keep the compiler and SDK aligned. Homebrew is optional for source installation and development checks; it is not a runtime dependency.

## Install

```sh
git clone https://github.com/stephenlclarke/aws-auto-approve.git
cd aws-auto-approve
make all
make install
"$HOME/.local/bin/aws-auto-approve" --help
```

The installer puts the app in `~/Applications/AWS Auto Approve.app` and links its executable at `~/.local/bin/aws-auto-approve`. It refuses to overwrite an existing installation. The bundle has a local ad-hoc signature. It is not Developer ID signed or notarised. No public release or Homebrew tap cask is published yet. To build through Homebrew from this checkout:

```sh
brew install --HEAD --formula ./Formula/aws-auto-approve.rb
```

That installs the helper into Homebrew's prefix. Use `brew --prefix aws-auto-approve` to locate its app bundle for Granted configuration. Do not also run `make install` unless you deliberately want a separate user installation.

## Connect Granted and direnv

In `~/.granted/config`, set the existing `CustomSSOBrowserPath` key to the installed executable's absolute path:

```toml
CustomSSOBrowserPath = "/Users/YOUR_USERNAME/Applications/AWS Auto Approve.app/Contents/MacOS/aws-auto-approve"
```

Use your actual home directory. Back up the file before editing. If an `SSOBrowserLaunchTemplate` is present, it takes precedence in Granted; remove or adjust that existing override deliberately. The installer does not change your Granted configuration or `.envrc`.

Granted 0.40.0 launches an unrecognised custom browser executable directly with the URL as its argument. Your existing direnv/Granted command can remain in place. The helper waits for approval while Granted keeps polling AWS for credentials. The helper's exit status proves only the approval page result; the initiating CLI must still finish successfully.

On first use, sign in inside the app's window and complete MFA. Its WebKit session is separate from Safari or Chrome. Later requests can complete without showing a window while that session remains valid. Login pages and unfamiliar screens open visibly. Some identity providers prohibit embedded browser login or need a flow this app does not support; those environments require a different integration.

Granted's URL-only hand-off does not include the CLI confirmation code. If AWS shows a **Confirm code** screen, this mode leaves confirmation to you. It still handles the later **Allow** screen. Use the input mode below when both the URL and code are available.

## Direct and streaming input

```sh
aws-auto-approve --code ABCD-EFGH 'https://eu-west-1.signin.aws/platform/authorize?request_uri=EXAMPLE'
aws-auto-approve --stdin
```

`--stdin` reads live authentication messages, extracts supported URLs and `Code: ABCD-EFGH` lines, and starts processing before EOF. It handles split lines and terminal colour codes. Feed only the authentication messages for one request; avoid also opening the same request in another browser. A code arriving after navigation updates the check. If confirmation appears before the code arrives, it remains manual until the code is available.

Do not pipe `direnv export zsh` or credential-bearing command output into this app. That stream controls shell exports and may contain credentials. Prefer Granted's custom-browser integration. The helper does not echo or save its input. Each invocation accepts one request and holds a session lock; concurrent requests fail clearly rather than race over the same session. Retry the initiating command after the active approval completes.

`--visible` shows the window immediately. `--timeout SECONDS` sets a 1-900 second deadline (default 180). Closing the window cancels. Exit codes: 0 approval completed; 1 failure or timeout; 2 cancelled. The app emits only fixed status messages to stderr.

## Approval boundary

Only HTTPS regional `signin.aws` or legacy `device.sso.REGION.amazonaws.com` approval URLs are accepted. Automatic clicks run only at the initial request's host and path. Credentials, ports and unrelated paths in the input URL are rejected. Identity-provider redirects are interactive; HTTP and external-app navigation are blocked. A supplied confirmation code must match the page. Missing codes require manual confirmation. Ambiguous, disabled and hidden buttons are never clicked.

The input is a trust boundary: the helper cannot prove who created a pasted URL. Supply requests started by your own local authentication command. It does not automate passwords, MFA, organisation policy, other consent screens or arbitrary websites. See [security notes](SECURITY.md).

WebKit keeps its own persistent website data. The session lock lives in `~/Library/Application Support/AWSAutoApprove`. Website data is managed by WebKit under the app's macOS identity. Sign out in the app's identity-provider page to revoke its browser session; AWS session revocation remains an AWS/identity-provider operation. Removing the executable alone does not revoke server-side sessions.

## Development and checks

| Command | Result |
| --- | --- |
| `make build` | Debug build, compiler warnings treated as errors |
| `make test` | Input tests and real WebKit DOM fixtures, with Swift coverage |
| `make unit-test` | Isolated parser, URL policy and option tests |
| `make coverage` | Full tests and Sonar generic coverage report |
| `make bundle` | Release build and locally signed app bundle |
| `make install` | Install without changing Granted or shell settings |
| `make run ARGS='--help'` | Run the debug executable |
| `make lint` | Markdown, workflow and shell syntax checks |
| `make sonar` | Analyse the current commit using `SONAR_TOKEN` |
| `make clean` | Remove generated build outputs |

WebKit tests require a macOS user session and permission to start WebKit processes. Fixtures exercise actual native DOM button clicks, code mismatch, missing codes, wrong origins, hidden/disabled/ambiguous controls, completion and login fallback. They do not authenticate to AWS or use real credentials. Coverage reports include all maintained Swift application sources; UI orchestration coverage can be lower than core policy coverage. Coverage is reported without exclusions for untested UI code.

CI builds and tests on macOS, checks installation, and publishes the app bundle as an Actions artifact. Main pushes also publish SonarQube analysis and wait for its quality gate. Dependabot checks pinned GitHub Actions daily; there are no external Swift packages. Dependency Review runs on pull requests. The README badge set follows `stephenlclarke/l337`, with release and Homebrew labels adjusted to the delivery that exists here.

## Remove or update

Restore your previous Granted browser setting first. Remove the installed `aws-auto-approve` symlink and app bundle, then run `make install` for an update. The installer preserves existing installations until you move them aside. Keep browser session data if you want to retain sign-in; removing it requires deliberate WebKit data removal and does not replace server-side revocation.

## Licence

[MIT](LICENSE), copyright 2026 Stephen Clarke.
