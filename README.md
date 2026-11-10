# AWS Auto Approve

<p>
  <img align="left" hspace="20" src="Resources/AppIcon.png" width="200" alt="AWS Auto Approve icon: a browser window with a green approval tick" />
  <a href="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/ci.yml?query=branch%3Amain"><img alt="CI" src="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/ci.yml/badge.svg?branch=main" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/unit-tests.yml?query=branch%3Amain"><img alt="Unit Tests" src="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/unit-tests.yml/badge.svg?branch=main" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/codeql.yml?query=branch%3Amain"><img alt="CodeQL" src="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/codeql.yml/badge.svg?branch=main" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/dependency-review.yml?query=event%3Apull_request"><img alt="Dependency Review" src="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/dependency-review.yml/badge.svg?event=pull_request" /></a>
  <a href="https://github.com/stephenlclarke/homebrew-tap/actions/workflows/homebrew.yml?query=branch%3Amain"><img alt="Homebrew tap" src="https://github.com/stephenlclarke/homebrew-tap/actions/workflows/homebrew.yml/badge.svg?branch=main" /></a>
</p>

<p>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Quality Gate Status" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=alert_status" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Coverage" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=coverage" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Bugs" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=bugs" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Code Smells" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=code_smells" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Security Rating" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=security_rating" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Maintainability Rating" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=sqale_rating" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Duplicated Lines" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=duplicated_lines_density" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Lines of Code" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=ncloc" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Reliability Rating" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=reliability_rating" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Vulnerabilities" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=vulnerabilities" /></a>
  <a href="https://sonarcloud.io/summary/new_code?id=stephenlclarke_aws-auto-approve"><img alt="Technical Debt" src="https://sonarcloud.io/api/project_badges/measure?project=stephenlclarke_aws-auto-approve&amp;metric=sqale_index" /></a>
</p>

<p>
  <img alt="Repo Visitors" src="https://visitor-badge.laobi.icu/badge?page_id=stephenlclarke.aws-auto-approve" />
</p>
<br clear="left" />
<br>

AWS Auto Approve is a native Swift app for macOS that clicks **Allow** on locally initiated AWS SSO requests and closes when approval completes. It works directly with AWS CLI and uses the built-in WebKit browser.

Sign in and complete DUO or other MFA when prompted. Later requests can approve automatically while the saved browser session remains valid.

## Install and use

```sh
brew tap stephenlclarke/tap
brew install --HEAD stephenlclarke/tap/aws-auto-approve
aws-auto-approve-login your-profile
```

Use `aws-auto-approve-login --if-needed your-profile` to reuse valid credentials before starting a new sign-in.

- [INSTALL.md](docs/INSTALL.md): Homebrew installation, zsh, AWS profiles, direnv, upgrades and removal.
- [BUILD.md](docs/BUILD.md): build from source, run tests and create a local app bundle.
- [SECURITY.md](SECURITY.md): approval boundaries and reporting vulnerabilities.

Requires macOS 14 or later. The current Homebrew formula builds from source and needs Xcode 16 or later. Builds have a local ad-hoc signature; a notarised installer is not yet available.

## Licence

[MIT](LICENSE), copyright 2026 Stephen Clarke.
