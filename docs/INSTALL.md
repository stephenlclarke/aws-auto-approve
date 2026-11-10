# Install AWS Auto Approve

AWS Auto Approve uses macOS WebKit to approve a locally initiated AWS SSO request. Choose either the AWS CLI wrapper or an existing Granted setup. **Granted is optional.** The app does not store AWS role credentials; the CLI that starts sign-in manages them.

- [Without Granted](#sign-in-without-granted): use `aws-auto-approve-login` with AWS CLI v2.
- [With Granted](#sign-in-with-granted): set the native helper as Granted's custom SSO browser.

## Requirements

- macOS Sonoma 14 or later.
- Full Xcode 16 or later for the current source-based Homebrew formula. See [build prerequisites](BUILD.md#requirements).
- Homebrew and AWS CLI v2.
- An AWS IAM Identity Center profile that your organisation permits you to use.

Install Homebrew from [brew.sh](https://brew.sh/) if needed. For a manual source build or development setup, use [BUILD.md](BUILD.md). Install AWS CLI if it is missing:

```sh
brew install awscli
aws --version
```

## Install through Homebrew

```sh
brew tap stephenlclarke/tap
brew install --HEAD stephenlclarke/tap/aws-auto-approve
brew test stephenlclarke/tap/aws-auto-approve
aws-auto-approve --help
aws-auto-approve-login --help
```

If Homebrew asks you to trust this tap, review its [formula](https://github.com/stephenlclarke/homebrew-tap/blob/main/Formula/aws-auto-approve.rb) before approving it. The formula builds the native app and installs two commands plus zsh completions. It does not change shell files, AWS profiles or directory permissions. The app has a local ad-hoc signature. A notarised binary release is not yet available.

Use the fully qualified tap name in install and upgrade commands. Installing a loose local formula file is not the supported route.

## Make the commands available in zsh

If `command -v brew` and `command -v aws-auto-approve-login` already work in a fresh terminal, keep your current Homebrew configuration.

Otherwise, add the line for your Mac to `~/.zprofile` once:

```zsh
# Apple silicon
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Intel Mac: use this block instead of the Apple silicon block.
# if [[ -x /usr/local/bin/brew ]]; then
#   eval "$(/usr/local/bin/brew shellenv)"
# fi
```

For native zsh completion, keep your existing completion framework. If you have none, add this to `~/.zshrc`:

```zsh
autoload -Uz compinit
compinit
```

Open a new terminal, then check:

```zsh
command -v aws-auto-approve
command -v aws-auto-approve-login
aws-auto-approve-login --help
```

Homebrew installs completion files in its normal `share/zsh/site-functions` directory. No shell alias, background service or credentials exported by a login wrapper are needed. If an older `~/.local/bin/aws-auto-approve` takes precedence, move that old symlink aside and run `rehash`. Keep its old app bundle until the Homebrew installation has passed a real sign-in test.

## Configure your AWS profile

If you already use a working IAM Identity Center profile, keep it. To create one:

```sh
aws configure sso --profile work
```

Use the start URL, SSO region, account and role supplied by your organisation. `work` is only an example profile name. Do not put access keys or passwords in shell files or `.envrc`.

For the AWS CLI route only, if migrating a profile that has a `credential_process` pointing to Granted, replace that provider with a standard AWS CLI SSO profile first. Keep existing Granted profiles when using the Granted route. Do not remove unrelated credential providers. The app cannot convert profile definitions for you.

## Sign in without Granted

```sh
aws-auto-approve-login work
aws sts get-caller-identity --profile work
```

The wrapper runs `aws sso login --use-device-code --no-browser` and streams only its authentication messages to the native helper. It preserves failures from either command and verifies role access after login. Authentication URLs and codes are not echoed by the wrapper.

Automatic redirects and approval run in the background. The app creates a window when stable, visible login fields, MFA frames or other manual controls need attention. The first request may therefore open a window for your work account login and DUO or other MFA. Use the account that belongs to your organisation. Later requests can approve automatically while the app's WebKit session remains valid. That session is separate from Safari and Chrome. Normal organisation sign-in and MFA rules still apply.

To keep a valid AWS session and sign in only when needed:

```sh
aws-auto-approve-login --if-needed work
```

This first makes a read-only STS identity request. If it succeeds, the wrapper returns without opening the app. Otherwise it signs in and checks role access again. A permission or configuration failure can still require repair; sign-in does not grant new permissions.

## Sign in with Granted

Use this route if you already use Granted to assume AWS roles. Complete Granted's normal installation and shell setup using its [official guide](https://docs.granted.dev/). Keep your existing AWS profiles and credential providers. Install AWS Auto Approve through Homebrew as described above.

Find the native helper's stable executable path:

```sh
command -v aws-auto-approve
```

Back up `~/.granted/config` before editing it. Set its existing top-level `CustomSSOBrowserPath` entry to the exact absolute path printed above. Put it before any TOML `[section]` headers. For a standard Apple silicon Homebrew installation:

```toml
CustomSSOBrowserPath = "/opt/homebrew/bin/aws-auto-approve"
```

For standard Intel Homebrew, the path is `/usr/local/bin/aws-auto-approve`. Use the executable path, without arguments; do not use the `.app` directory or a versioned Cellar path. Preserve the other configuration entries and your AWS console browser selection.

An existing `[SSOBrowserLaunchTemplate]` overrides `CustomSSOBrowserPath`. If you want to use the custom path above, remove that SSO template block after backing it up. Preserve unrelated launch templates. See [Granted configuration](https://docs.granted.dev/configuration/) and its [browser launch behaviour](https://github.com/fwdcloudsec/granted/blob/main/pkg/idclogin/browser.go).

Start your usual role command:

```sh
assume work
aws sts get-caller-identity
```

Granted passes its authorisation URL directly to the helper. Granted may still print its own URL/code prompts; the helper does not filter its output. Do not record or share those prompts, or pipe credential output into the helper. The helper keeps automatic approval in the background and shows login or DUO/MFA when needed. Granted does not pass the expected confirmation code as `--code`, so a **Confirm code** screen requires manual confirmation.

Granted owns authentication and role credentials. It launches the browser helper separately, so closing the helper does not cancel Granted's waiting login. Verify the final Granted command and role access; the AWS CLI wrapper's process-cancellation and final STS checks apply to the route without Granted.

To restore Granted's normal SSO browser, clear `CustomSSOBrowserPath` or restore your saved SSO launch template. Do this before uninstalling AWS Auto Approve if Granted still points to its executable.

## Use direnv without Granted for directory entry

Install direnv if needed, then add its hook to `~/.zshrc` once:

```zsh
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
```

Create `.envrc` in the project directory:

```sh
aws-auto-approve-login --if-needed work || return
export AWS_PROFILE=work
```

Keep local `.envrc` files out of version control unless your team deliberately shares a profile-neutral version. Review the file, then authorise it:

```sh
direnv allow
```

If the directory needs two roles warmed, call the wrapper for each profile in the required order, then set `AWS_PROFILE` to the intended final profile. Existing Granted `assume ... --exec true` lines can be replaced with these wrapper calls. Do not source `assume`, pipe `direnv export zsh` into the helper, or print temporary credentials.

The wrapper is a normal executable, so direnv can call it without relying on interactive shell functions. During an expired session, directory entry waits for sign-in. The direnv slow-operation notice can still appear when login or MFA takes time.

## Direct use and limits

`aws-auto-approve` also accepts a supported AWS authorisation URL with optional `--code`, or authentication messages through `--stdin`. Other tools can use those interfaces without AWS CLI, provided they initiate their own request and handle token exchange.

Only recognised AWS approval pages receive automatic clicks. Other pages receive a read-only check for visible manual controls; credential values are not read. Use `--visible` in direct helper mode to show its window immediately when diagnosing an unfamiliar sign-in page. Code mismatches stop approval. Login, MFA and unfamiliar pages remain interactive. The helper accepts one request at a time; retry after an active request finishes. A **Confirm code** page requires the expected code or manual confirmation. Some identity providers prohibit embedded browsers.

Do not save real authentication URLs or codes in scripts, command history, issues or documentation. The higher-level login wrapper avoids putting the URL in a shell command.

## Upgrade

```sh
brew update
brew upgrade --fetch-HEAD stephenlclarke/tap/aws-auto-approve
brew test stephenlclarke/tap/aws-auto-approve
```

Keep integrations pointed at Homebrew's normal commands, not a versioned Cellar path. The app's bundle identity remains stable across upgrades. Moving an installation can affect the session data WebKit finds, so the first login after migration may need MFA again.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Command not found | Check Homebrew shell setup in a new terminal and run `rehash`. |
| Xcode build failure | Check `xcode-select -p`, Xcode version and licence acceptance. |
| Wrong Microsoft account | Select your organisation's account. Start a fresh request if the error page offers no account switch. |
| No approval URL received | Check the AWS profile and CLI version. The wrapper explicitly selects device-code mode. |
| Credentials still fail | Run `aws sts get-caller-identity --profile work` and check account/role permissions. |
| Another approval is active | Complete or close its window, then retry. |
| Completion missing | Check that Homebrew's zsh completion directory is in `fpath`, then restart zsh. |

To inspect an AWS CLI sign-in failure directly, run `aws sso login --use-device-code --no-browser --profile work` yourself. It prints a live URL and code; do not share or record that output.

## Remove

Remove or replace this tool's `.envrc` calls before uninstalling. If using Granted, also clear its custom SSO browser path or restore the previous setting:

```sh
brew uninstall stephenlclarke/tap/aws-auto-approve
```

Shell hooks and profile settings remain yours to maintain. Uninstalling does not sign out AWS CLI or revoke server-side sessions. Use `aws sso logout` only when you intend to clear the AWS CLI SSO cache for all profiles. The app's WebKit session is separate.
