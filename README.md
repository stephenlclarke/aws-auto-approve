# AWS Auto Approve

<p align="center">
  <a href="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/ci.yml"><img alt="CI on main" src="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/ci.yml/badge.svg" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/unit-tests.yml"><img alt="Unit tests on main" src="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/unit-tests.yml/badge.svg" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/codeql.yml"><img alt="CodeQL" src="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/codeql.yml/badge.svg?branch=main" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/dependency-review.yml"><img alt="Dependency Review" src="https://github.com/stephenlclarke/aws-auto-approve/actions/workflows/dependency-review.yml/badge.svg" /></a>
  <a href=".github/dependabot.yml"><img alt="Dependabot: daily updates" src="https://img.shields.io/badge/Dependabot-daily_updates-blue.svg" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/security"><img alt="GitHub security" src="https://img.shields.io/badge/Security-GitHub-blue.svg" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/releases"><img alt="Source preview" src="https://img.shields.io/badge/Release-source_preview-orange.svg" /></a>
  <a href="INSTALL.md"><img alt="Homebrew source installation" src="https://img.shields.io/badge/Homebrew-install-blue.svg" /></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/github/license/stephenlclarke/aws-auto-approve" /></a>
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
  <a href="https://github.com/stephenlclarke/aws-auto-approve/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/stephenlclarke/aws-auto-approve" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/forks"><img alt="Forks" src="https://img.shields.io/github/forks/stephenlclarke/aws-auto-approve" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/issues"><img alt="Open issues" src="https://img.shields.io/github/issues/stephenlclarke/aws-auto-approve" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/pulls"><img alt="Open pull requests" src="https://img.shields.io/github/issues-pr/stephenlclarke/aws-auto-approve" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/stephenlclarke/aws-auto-approve/main" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve"><img alt="Repository size" src="https://img.shields.io/github/repo-size/stephenlclarke/aws-auto-approve" /></a>
  <a href="https://github.com/stephenlclarke/aws-auto-approve"><img alt="Primary language" src="https://img.shields.io/github/languages/top/stephenlclarke/aws-auto-approve" /></a>
</p>

AWS Auto Approve is a native Swift app for macOS that clicks **Allow** on locally initiated AWS SSO requests and closes when approval completes. It works directly with AWS CLI and uses the built-in WebKit browser.

Sign in and complete DUO or other MFA when prompted. Later requests can approve automatically while the saved browser session remains valid.

## Install and use

```sh
brew tap stephenlclarke/tap
brew install --HEAD stephenlclarke/tap/aws-auto-approve
aws-auto-approve-login your-profile
```

Use `aws-auto-approve-login --if-needed your-profile` to reuse valid credentials before starting a new sign-in.

- [INSTALL.md](INSTALL.md): Homebrew installation, zsh, AWS profiles, direnv, upgrades and removal.
- [BUILD.md](BUILD.md): build from source, run tests and create a local app bundle.
- [SECURITY.md](SECURITY.md): approval boundaries and reporting vulnerabilities.

Requires macOS 14 or later. The current Homebrew formula builds from source and needs Xcode 16 or later. Builds have a local ad-hoc signature; a notarised installer is not yet available.

## Licence

[MIT](LICENSE), copyright 2026 Stephen Clarke.
