# Install AWS Auto Approve

AWS Auto Approve uses macOS WebKit to approve a locally initiated AWS SSO request. Choose either the AWS CLI wrapper or an existing Granted setup. **Granted is optional.** The app does not store AWS role credentials; the CLI that starts sign-in manages them.

- [Without Granted](#sign-in-without-granted): use `aws-auto-approve-login` with AWS CLI v2.
- [With Granted](#sign-in-with-granted): set the native helper as Granted's custom SSO browser.

## Requirements

- macOS Sonoma 14 or later.
- Apple Silicon or Intel Mac. Homebrew installs the matching prebuilt release; Xcode is needed only for [source builds](BUILD.md#requirements).
- Homebrew and AWS CLI v2.
- An AWS IAM Identity Center profile that your organisation permits you to use.

Install Homebrew from [brew.sh](https://brew.sh/) if needed. For a manual source build or development setup, use [BUILD.md](BUILD.md). Install AWS CLI if it is missing:

```sh
brew install awscli
aws --version
```

## Configure automatically

Use [`configure.sh`](../configure.sh) for a guided installation. It follows the same pattern as the reference Mac: Homebrew zsh as a login shell in Ghostty, Starship before the direnv hook, and a local `.envrc` that checks profiles in order before selecting the final `AWS_PROFILE`.

Download the script, inspect it, then preview or run it:

```sh
aws_setup_dir="$(mktemp -d)"
curl --fail --silent --show-error --location --proto '=https' \
  https://raw.githubusercontent.com/stephenlclarke/aws-auto-approve/main/configure.sh \
  -o "$aws_setup_dir/configure.sh"
less "$aws_setup_dir/configure.sh"
bash "$aws_setup_dir/configure.sh" --dry-run
bash "$aws_setup_dir/configure.sh"
```

The script checks for a working Granted installation and offers it as the default. Otherwise, it recommends AWS CLI without Granted. Press Enter to confirm, choose `g` for Granted or `a` for AWS CLI. You can also select a route explicitly with `--with-granted` or `--without-granted`.

It installs missing Homebrew dependencies, including AWS CLI v2, zsh, Ghostty, Starship, direnv and Granted when selected, then installs or upgrades the prebuilt AWS Auto Approve release. It does not download full Xcode. Homebrew can need its normal Command Line Tools or administrator approval; AWS sign-in and MFA can need your input. The account's default shell, terminal appearance and unrelated AWS profiles remain unchanged.

You can supply projects and profiles instead of entering them at prompts:

```sh
bash "$aws_setup_dir/configure.sh" --without-granted \
  --project "$HOME/github/project-one" \
  --profile work-secrets --profile work-readonly \
  --active-profile work-readonly \
  --project "$HOME/github/project-two" --profile another-readonly
```

Directories must already exist. Profile names in this script use letters, digits, dots, underscores, `@`, `+` or `-`. Each `--profile` after `--project` belongs to that project; the last profile is active unless you supply `--active-profile`. A standalone `--profile work` configures and verifies that profile without requiring a project. Missing profile definitions prompt for your organisation's SSO settings. Existing incomplete profiles or unrelated credential providers need manual review; the script does not overwrite them.

The script follows dot-file symlinks and uses named managed blocks. It backs up each changed target once per run under `~/Library/Application Support/AWSAutoApprove/configure-backups/`. The printed `manifest.txt` maps originals to backups and lists new files. To undo configuration, restore those originals and remove only newly created files that you have not since edited. Installed packages and authentication sessions remain; use the removal section below if needed.

For existing projects, it migrates the exact AWS CLI wrapper lines shown in this guide. Other unmanaged AWS authentication commands and tracked `.envrc` files require private review first. It shows the proposed authentication block and asks before writing and authorising the complete `.envrc`. Granted projects use selected credential-process profiles, with role warming through the executable `assume --exec true`; they do not source its interactive alias into direnv. Only selected profiles change provider. The directory block clears inherited temporary AWS credential variables so they cannot override the chosen profile; direnv restores the prior environment when you leave.

The default run checks both commands, app signing, the Homebrew formula test, fresh zsh startup and real role access. Granted sign-in output remains private because it can include a live URL/code. Formula test failures are reported separately and return failure even when independent checks pass. `--skip-login` skips live sign-in and leaves `.envrc` untrusted for you to authorise later. `--dry-run` changes no files and does not sign in. After setup, open a fresh Ghostty window and check completion, the profile prompt, and directory entry/exit; the script reports those interactive checks as still required.

## Install and configure with Codex

Copy the complete Markdown block into Codex on the destination Mac. It directs Codex to use the same configure script, so installation rules have one maintained implementation.

````markdown
Install and configure AWS Auto Approve on this MacBook Pro using:
https://github.com/stephenlclarke/aws-auto-approve/blob/main/configure.sh

Read that script and the current INSTALL.md and BUILD.md first:
https://github.com/stephenlclarke/aws-auto-approve/blob/main/docs/INSTALL.md
https://github.com/stephenlclarke/aws-auto-approve/blob/main/docs/BUILD.md

Inspect the destination Mac and run the script's --dry-run mode. If Granted
is installed and works, offer "With Granted (default; already installed)"
and "Without Granted". Otherwise recommend "Without Granted (default)"
and offer to install Granted. Wait for me to confirm or switch.

Ask which existing project directories and profiles to configure, their
warm-up order and final active profile. Then run the reviewed script with
the selected --with-granted or --without-granted option and the grouped
--project, --profile and --active-profile arguments. Install the chosen
route's missing dependencies. Use the script's existing backups and managed
blocks rather than replacing my dot-files or building a second installer.

Let me complete administrator approval, credentials and DUO/MFA. Resume after a fixable prerequisite is ready. Never enable shell
tracing, dump my environment, print credentials or record authentication
URLs/codes. Preserve unrelated work and existing terminal appearance.

Check the script's result, then verify a fresh Ghostty login shell,
completion, Starship's active profile, and direnv entry/exit for each project.
A cached-session check alone does not prove browser approval works. Report
installed versions, changed files and backups, checks passed, rollback
instructions and any exact manual step still needed. Do not claim success
for skipped checks or automatically approve MFA.
````

### Why there are two commands

- `aws-auto-approve` is the native Swift/WebKit app. It receives an authorisation URL or authentication messages, handles supported AWS approval pages and shows a window for login or MFA. Granted calls this command directly. It does not fetch AWS role credentials.
- `aws-auto-approve-login` is the shell wrapper for AWS CLI. It starts sign-in for a profile, streams the request to the native app, handles cancellation and failures, then verifies role access through STS. Its `--if-needed` option reuses a valid session. Use this command from zsh and direnv when working without Granted.

## Install through Homebrew

```sh
brew tap stephenlclarke/tap
brew install stephenlclarke/tap/aws-auto-approve
brew test stephenlclarke/tap/aws-auto-approve
aws-auto-approve --help
aws-auto-approve-login --help
```

If Homebrew asks you to trust this tap, review its [formula](https://github.com/stephenlclarke/homebrew-tap/blob/main/Formula/aws-auto-approve.rb) before approving it. The formula installs the matching versioned Apple Silicon or Intel app package, verified by SHA-256, plus two commands and zsh completions. It does not change shell files, AWS profiles or directory permissions. Releases from 0.2.0 require Developer ID signing, Apple notarisation and an attached ticket. Earlier 0.1.x packages have ad-hoc signatures. Homebrew tests the installed signature and Gatekeeper assessment.

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

The wrapper prints `[v] [work] AWS session is ready` on stderr after it verifies role access, for both an existing session and a fresh sign-in. The message is green in a terminal and plain when redirected. Set `SCRIPT_COLOUR=off` or `NO_COLOR` to disable colour. It confirms access for the named profile; it does not change `AWS_PROFILE` or report a credential expiry time.

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
brew upgrade stephenlclarke/tap/aws-auto-approve
brew test stephenlclarke/tap/aws-auto-approve
```

Keep integrations pointed at Homebrew's normal commands, not a versioned Cellar path. The app's bundle identity remains stable across upgrades. Moving an installation can affect the session data WebKit finds, so the first login after migration may need MFA again.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Command not found | Check Homebrew shell setup in a new terminal and run `rehash`. |
| Old source installation | Run `brew update` and `brew reinstall stephenlclarke/tap/aws-auto-approve` to switch to the released package. |
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
