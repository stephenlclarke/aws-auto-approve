# Repository guidance

## Architecture and documentation

- Keep the app native Swift/WebKit, using Apple frameworks without external browser or automation-app dependencies.
- Keep the sign-in integration based on AWS CLI. Do not introduce a Granted dependency.
- Keep the README brief. Use [BUILD.md](BUILD.md) for development and [INSTALL.md](INSTALL.md) for user setup.
- Keep examples organisation-neutral. DUO and other MFA remain supported interactive steps.

## Authentication boundaries

- Automate only supported AWS approval pages for the locally supplied request. Preserve host, path and confirmation-code checks.
- Keep password entry, DUO and other MFA interactive. Never bypass organisation sign-in policy.
- Never log authentication URLs, codes, tokens, cookies or credentials. Do not enable shell tracing where startup files or environment variables may contain secrets.
- Preserve both AWS CLI and helper failures. Cancellation must stop the owned CLI process, and live input must be handled before EOF.
- Use synthetic authentication data in tests. Live sign-in checks must not publish real request data.

## Validation

- Run `make lint` after edits. Run `make test` for behaviour changes and `make bundle` for packaging changes.
- Add focused regression tests for changed approval, streaming, cancellation or exit-status behaviour.
- Native WebKit tests need a macOS user session. Use the Makefile's Xcode compiler selection and module-cache settings.
- Treat a completed approval page and successful CLI credential exchange as separate checks when validating live sign-in.

## Code Review Rules

- Flag changes that widen automatic approval, weaken code matching, expose authentication data, hide failures or leave sign-in processes running.
- Check that the Homebrew formula, login wrapper, completions and guides agree when installation or command behaviour changes.

## Delivery

- Work on a branch and open a pull request into protected `main`.
- Pass all required CI, unit and CodeQL checks before merging. Do not bypass failed or missing checks.
- Confirm main CI and its Sonar quality gate after merging. Keep badges linked to checks and delivery methods that exist.
