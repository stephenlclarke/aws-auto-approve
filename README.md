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

**Source preview, live-tested on 10 November 2026:** a CMC Microsoft/DUO sign-in completed in the native window. A second request reused the saved session, submitted the AWS approval automatically, completed the AWS token exchange and closed with exit code 0. Release and Homebrew badges describe the current source installation, not a signed downloadable release.

## Requirements

macOS 14 or later. Building needs Xcode with Swift 6 or later. The Makefile selects Xcode's bundled compiler to keep the compiler and SDK aligned. Homebrew is optional for source installation and development checks; it is not a runtime dependency.

## Install and integrate

Use the [installation guide](INSTALL.md) for Homebrew, zsh, AWS CLI profiles, direnv, upgrades and removal. The supported integration uses AWS CLI directly; Granted is not required.

```sh
brew tap stephenlclarke/tap
brew install --HEAD stephenlclarke/tap/aws-auto-approve
aws-auto-approve-login your-profile
```

`aws-auto-approve-login --if-needed your-profile` reuses valid AWS credentials before starting a new sign-in. It can also run from `.envrc`. Homebrew installs both commands and zsh completions.

For a local development build, use `make all` and `make install`. That separate installer puts an app in `~/Applications` and a symlink in `~/.local/bin`; it does not configure authentication. Prefer one installation route to avoid command shadowing.

## Direct and streaming input

```sh
aws-auto-approve --code ABCD-EFGH 'https://eu-west-1.signin.aws/platform/authorize?request_uri=EXAMPLE'
aws-auto-approve --stdin
```

`--stdin` reads live authentication messages, extracts supported URLs and `Code: ABCD-EFGH` lines, and starts processing before EOF. It handles split lines and terminal colour codes. Feed only the authentication messages for one request; avoid also opening the same request in another browser. A code arriving after navigation updates the check. If confirmation appears before the code arrives, it remains manual until the code is available.

Do not pipe `direnv export zsh` or credential-bearing command output into this app. That stream controls shell exports and may contain credentials. Prefer `aws-auto-approve-login`. The helper does not echo or save its input. Each invocation accepts one request and holds a session lock; concurrent requests fail clearly rather than race over the same session. Retry the initiating command after the active approval completes.

`--visible` shows the window immediately. `--timeout SECONDS` sets a 1-900 second deadline (default 180). Closing the window cancels. Exit codes: 0 approval completed; 1 failure or timeout; 2 cancelled. The app emits only fixed status messages to stderr.

## Approval boundary

Only HTTPS regional `signin.aws` or legacy `device.sso.REGION.amazonaws.com` approval URLs are accepted. Automatic clicks run only at the initial request's host and path, plus its matching `/platform/d-IDENTITYSTORE/login` redirect when the initial URL names that identity store. Credentials, ports and unrelated paths in the input URL are rejected. Identity-provider redirects are interactive; HTTP and external-app navigation are blocked. A supplied confirmation code must match the page. Missing codes require manual confirmation. Ambiguous, disabled and hidden buttons are never clicked.

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

WebKit tests require a macOS user session and permission to start WebKit processes. Fixtures exercise actual native DOM button clicks, code mismatch, missing codes, wrong origins, hidden/disabled/ambiguous controls, completion and login fallback. Automated tests do not authenticate to AWS or use real credentials. The separate live test described above used a fresh device-authorisation request; returned token contents were discarded. Coverage reports include all maintained Swift application sources; UI orchestration coverage can be lower than core policy coverage. Coverage is reported without exclusions for untested UI code. The local 24-test run measured 94% Swift line coverage, including application orchestration, streaming input, timeouts and cancellation.

CI builds and tests on macOS, checks installation, and publishes the app bundle as an Actions artifact. Main pushes also publish SonarQube analysis and wait for its quality gate. Dependabot checks pinned GitHub Actions daily; there are no external Swift packages. Dependency Review runs on pull requests. The README badge set follows `stephenlclarke/l337`, with release and Homebrew labels adjusted to the delivery that exists here.

## Remove or update

For Homebrew, follow [upgrade and removal](INSTALL.md#upgrade). For a local development installation, remove the installed `aws-auto-approve` symlink and app bundle, then run `make install` for an update. The installer preserves existing installations until you move them aside. Keep browser session data if you want to retain sign-in; removing it requires deliberate WebKit data removal and does not replace server-side revocation.

## Licence

[MIT](LICENSE), copyright 2026 Stephen Clarke.
