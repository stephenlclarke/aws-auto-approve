# Build AWS Auto Approve

Use this guide to build, test or change the app. For Homebrew installation and shell integration, use [INSTALL.md](INSTALL.md).

## Requirements

- macOS 14 or later.
- Full Xcode 16 or later, including Swift 6 or later, with its licence accepted.
- Git and the standard macOS build tools.

The app uses Apple frameworks and has no external Swift package dependencies. The AWS CLI login wrapper needs AWS CLI v2 when you run it.

Check your selected Xcode:

```sh
xcode-select -p
xcrun --toolchain XcodeDefault swift --version
```

If needed, select the Xcode installation you intend to use:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

The Makefile selects Xcode's bundled Swift compiler to keep the compiler and SDK aligned. It stores module caches inside `.build`.

## Clone and build

```sh
git clone https://github.com/stephenlclarke/aws-auto-approve.git
cd aws-auto-approve
make all
```

`make all` runs the tests, builds the release executable and creates `dist/AWS Auto Approve.app`. The bundle includes its approval script and receives a local ad-hoc signature. It is not Developer ID signed or notarised.

Check the built command:

```sh
"dist/AWS Auto Approve.app/Contents/MacOS/aws-auto-approve" --help
```

## Run or install a development build

```sh
make run ARGS='--help'
make install
```

The local installer puts the app in `~/Applications/AWS Auto Approve.app` and links its executable at `~/.local/bin/aws-auto-approve`. It refuses to overwrite an existing app or symlink and does not change authentication or shell settings.

This development installer installs only the native helper. Homebrew also installs `aws-auto-approve-login` and the zsh completions. Prefer Homebrew for the complete shell integration described in [INSTALL.md](INSTALL.md).

Avoid keeping a development command ahead of the Homebrew command in `PATH`. Check `command -v aws-auto-approve` after changing installation routes. To update a development installation, move its previous app and symlink aside before running `make install` again.

## Tests and checks

| Command | Result |
| --- | --- |
| `make build` | Debug build, with compiler warnings treated as errors |
| `make build-release` | Release executable |
| `make test` | Shell wrapper checks and native tests with Swift coverage |
| `make unit-test` | Shell wrapper checks and isolated core tests |
| `make coverage` | Full tests and `coverage.xml` for SonarQube |
| `make bundle` | Release build and locally signed app bundle |
| `make lint` | Markdown, workflow, shell syntax and zsh completion checks |
| `make sonar` | Analyse the current commit using `SONAR_TOKEN` |
| `make clean` | Remove generated build outputs |

Native WebKit tests need a macOS user session and permission to start WebKit processes. They check real DOM button clicks, code matching, input streaming, timeouts, cancellation and manual fallback. The shell checks use isolated command stubs. Automated tests do not authenticate to AWS or use real credentials.

`make lint` needs `markdownlint-cli` and `actionlint`. `make sonar` needs `sonar-scanner` and a valid `SONAR_TOKEN`. Install these development tools through your normal package manager. Keep tokens out of shell history and source control.

## CI

GitHub CI runs the native and shell tests, produces coverage, builds the app and checks installation. Main pushes also publish SonarQube analysis and wait for its quality gate. The app bundle is available as an Actions artifact.

CodeQL scans Swift, the embedded JavaScript, the Homebrew Ruby formula and GitHub Actions workflows on main pushes, pull requests and a weekly schedule. Swift analysis traces a fresh `make build`; the other languages use build-free analysis. Results appear in GitHub code scanning.

Dependabot checks pinned GitHub Actions daily. Dependency Review runs on pull requests.
