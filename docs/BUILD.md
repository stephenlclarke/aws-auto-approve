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

## App icon

`Resources/AppIcon.png` is the source artwork used by the README and app. `Tools/build-icon.sh` uses macOS `sips` and `iconutil` to generate the standard icon sizes and `.build/AppIcon.icns`. `make bundle` installs that icon in the app's resources and declares it in `Info.plist` before signing. See [artwork provenance](../Resources/ICON.md).

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
| `make resolve` | Resolve package metadata without building application targets |
| `make test-asan` | Full native tests with Address Sanitizer in a separate build directory |
| `make test-tsan` | Full native tests with Thread Sanitizer in a separate build directory |
| `make build` | Debug build, with compiler warnings treated as errors |
| `make build-release` | Release executable |
| `make configure ARGS='--dry-run'` | Preview the guided Mac setup without installing or changing configuration |
| `make test` | Shell wrapper checks and native tests with Swift coverage |
| `make unit-test` | Shell wrapper checks and isolated core tests |
| `make coverage` | Full tests and `coverage.xml` for SonarQube |
| `make bundle` | Release build and locally signed app bundle |
| `make lint` | Markdown, workflow, shell syntax and zsh completion checks |
| `make sonar` | Analyse the current commit using `SONAR_TOKEN` |
| `make clean` | Remove generated build outputs |

Native WebKit tests need a macOS user session and permission to start WebKit processes. They check real DOM button clicks, code matching, input streaming, timeouts, cancellation and manual fallback. The shell checks use isolated command stubs and temporary Git histories to verify workflow path filtering. Window tests verify that automatic redirects do not create a window and that stable manual controls do. ASAN and TSAN each run the full native suite in their own build directory; the command-line tests use the executable from that same directory. Automated tests do not authenticate to AWS or use real credentials.

`make lint` needs `markdownlint-cli`, `actionlint` and `shellcheck`. `make sonar` needs `sonar-scanner` and a valid `SONAR_TOKEN`. Install these development tools through your normal package manager. Keep tokens out of shell history and source control.

`Tests/Shell/configure.sh` runs the configure script and its file-editing functions in temporary homes, with installers and authentication commands replaced by stubs. It checks route defaults, profile conversion, shared-session preservation, managed blocks, backups, symlinks, project integration and failure handling. It does not install packages or use live credentials. The tests run through `make test` and `make unit-test`.

## CI

GitHub CI runs the native and shell tests, produces coverage, builds the app and checks installation. ASAN and TSAN run as separate parallel jobs, so sanitizer coverage does not serialise the main quality job. Actions use Node 24 runtimes. New commits cancel superseded runs for the same workflow, event and PR/ref. Main pushes that run the full workload also publish SonarQube analysis using the official scanner action and wait for its quality gate, without installing the scanner through Homebrew each time. The app bundle is available as an Actions artifact.

Automatic runs use the following path rules:

| Changed files | Main push | Pull request |
| --- | --- | --- |
| Only the root `README.md` or files in any `docs/` folder | Workflows are not triggered | Ubuntu path checks run; build, test and scan workloads are skipped |
| Source, build, workflow or any other files | Full workloads | Full workloads |

The named PR checks remain available for branch protection. Each dependent job verifies that classification succeeded and returned a valid decision; an invalid Git comparison fails the checks. Filtering uses the whole pull request, so a later documentation-only commit cannot skip checks while that PR still contains source changes. Manual CI, unit-test and CodeQL runs, plus scheduled scans, always run in full. Unit tests run on main pushes and pull requests, without a duplicate branch-push run.

CodeQL scans Swift, the embedded JavaScript, the Homebrew Ruby formula and GitHub Actions workflows on main pushes, pull requests and a weekly schedule. Swift analysis pins Xcode 26.3 on the native Intel `macos-26-intel` runner, matching the tracer's x86_64 architecture without Rosetta. App, ASAN and TSAN jobs remain native Apple Silicon builds. See [CodeQL platform requirements](https://codeql.github.com/docs/codeql-overview/system-requirements/). Before starting the tracer, it resolves the compiler path and package metadata with `make resolve`; this does not compile application targets. It then traces a fresh `make build`, without restoring compiled app objects from a cache; the other languages use build-free analysis. Results appear in GitHub code scanning.

Dependabot checks pinned GitHub Actions daily. Dependency Review runs on pull requests.

## Versioning and releases

Use Conventional Commits for commits and squash PR titles. `feat:` produces a minor release, `fix:` and `perf:` produce patches, and `!` or a `BREAKING CHANGE:` footer produces a major release. Documentation-only commits do not produce a release. The initial feature release is `0.1.0`. Release tooling uses the semantic-release Conventional Commit analyser and release-note generator; Node 24 and npm are development/CI tools only.

Run `npm ci --ignore-scripts`, `npm test` and `npm run release -- --dry-run` to check the release plan. The dry run reads public release history and local commits; it does not build, tag or publish. Locked dependencies are audited with `npm audit`.

After the current main commit passes CI, unit tests, ASAN, TSAN, CodeQL and `release-tools`, the release workflow builds separate arm64 and x86_64 packages with their semantic version in the app bundle. It verifies each architecture, macOS 14 deployment target and app signature, then publishes archives, `SHA256SUMS`, release notes and a generated Homebrew formula. Assets are uploaded to a draft first. An existing published release is never overwritten. No version commit is pushed to protected main.

The Homebrew tap checks for a new release hourly, verifies the released formula checksum and opens a single-formula bot PR. It explicitly runs the required Homebrew check and enables protected auto-merge. A review-only owner token, limited to the tap and pull-request writes, supplies its required owner review; branch protection is not relaxed. See the tap installation guide for the AWS_AUTO_APPROVE_REVIEW_TOKEN setup. The updater refuses other authors or extra changed files. A manual tap workflow dispatch can pick up a new release sooner.

`bash Tools/package-release.sh 0.1.0` builds release packages locally without publishing them. Full Xcode is required here. Normal source bundles use development version `0.0.0` unless `APP_VERSION` is supplied. The Homebrew formula template is `Formula/aws-auto-approve.rb.in`; packaging inserts the version and archive checksums.
