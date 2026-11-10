# Install AWS Auto Approve

AWS Auto Approve uses macOS WebKit to approve an AWS CLI sign-in request. This guide uses AWS CLI v2 directly. **Granted is not required or used.** The app does not store AWS role credentials; AWS CLI manages them in its normal cache.

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

If migrating a profile that has a `credential_process` pointing to Granted, replace that provider with a standard AWS CLI SSO profile first. Do not remove unrelated credential providers. The app cannot convert profile definitions for you.

## Sign in without Granted

```sh
aws-auto-approve-login work
aws sts get-caller-identity --profile work
```

The wrapper runs `aws sso login --use-device-code --no-browser` and streams only its authentication messages to the native helper. It preserves failures from either command and verifies role access after login. Authentication URLs and codes are not echoed by the wrapper.

The first request may open a window for your work account login and DUO or other MFA. Use the account that belongs to your organisation. Later requests can approve automatically while the app's WebKit session remains valid. That session is separate from Safari and Chrome. Normal organisation sign-in and MFA rules still apply.

To keep a valid AWS session and sign in only when needed:

```sh
aws-auto-approve-login --if-needed work
```

This first makes a read-only STS identity request. If it succeeds, the wrapper returns without opening the app. Otherwise it signs in and checks role access again. A permission or configuration failure can still require repair; sign-in does not grant new permissions.

## Use direnv for directory entry

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

Only recognised AWS approval pages receive automatic clicks. Code mismatches stop approval. Login, MFA and unfamiliar pages remain interactive. The helper accepts one request at a time; retry after an active request finishes. A **Confirm code** page requires the expected code or manual confirmation. Some identity providers prohibit embedded browsers.

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

Remove or replace this tool's `.envrc` calls before uninstalling:

```sh
brew uninstall stephenlclarke/tap/aws-auto-approve
```

Shell hooks and profile settings remain yours to maintain. Uninstalling does not sign out AWS CLI or revoke server-side sessions. Use `aws sso logout` only when you intend to clear the AWS CLI SSO cache for all profiles. The app's WebKit session is separate.
