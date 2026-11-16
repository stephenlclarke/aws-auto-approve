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

## Install and configure with Codex

Copy the whole Markdown block below into Codex on the Mac you want to configure. Codex first checks for Granted and offers it as the default when it is installed and working. Otherwise, it recommends the route without Granted. Confirm that suggestion or choose the other route; Codex then configures it and installs any missing dependencies. You do not need to fill in placeholders before pasting. Apple sign-in, administrator approval, licence acceptance and AWS login/MFA can still need your input.

The reference Mac uses Homebrew zsh as a login shell in Ghostty, with Starship initialised before the direnv hook. Local, Git-ignored `.envrc` files check the required AWS profiles in order, then export the final `AWS_PROFILE`. Starship displays that active profile; the login wrapper reports each verified profile. The prompt adapts this pattern to the destination Mac without copying private profile names, accounts or credentials.

````markdown
Install and configure AWS Auto Approve on this MacBook Pro. Do the work,
including dependency installation and validation, rather than only giving
me commands to run.

Read the current installation guide and build requirements first:
https://github.com/stephenlclarke/aws-auto-approve/blob/main/docs/INSTALL.md
https://github.com/stephenlclarke/aws-auto-approve/blob/main/docs/BUILD.md

1. Before making changes, detect whether Granted is installed and works.
   Check command resolution in the actual zsh login environment, existing
   Homebrew installations and Granted's version output. Do not assume a
   missing PATH entry means it is absent or install a duplicate copy.
   If Granted works, ask: "Granted is installed. Use it with AWS Auto
   Approve (default), or configure without Granted?" Otherwise offer
   "Without Granted (default)" and "Install and use Granted". If it is
   present but broken, explain the problem and offer repair as part of
   the Granted option. Explain that without Granted uses AWS CLI directly;
   with Granted keeps its role-switching commands and uses AWS Auto
   Approve as its SSO browser. Wait for me to confirm or switch the
   suggested route before configuring it; silence is not confirmation.
   Also ask which project directories and AWS profiles to configure,
   their warm-up order and the final active profile for each directory.
   Offer existing profile names without exposing their credentials. Ask
   for missing SSO setup details only if a suitable profile does not exist.

2. Inspect macOS, CPU architecture, Homebrew, selected Xcode/Swift,
   AWS CLI, zsh, Ghostty, Starship and direnv. Inspect the effective
   ZDOTDIR, shell startup files, sourced configuration, PATH, fpath,
   STARSHIP_CONFIG, Ghostty configuration and selected AWS profiles.
   Read only the configuration needed for this task. Preserve unrelated
   settings and work. Back up each file before changing it, follow
   symlink targets and avoid duplicate hooks, aliases or PATH entries.

3. Install all missing dependencies for the chosen setup automatically.
   Use Homebrew's official installer if needed and its detected prefix,
   not a prefix copied from another Mac. Install AWS CLI v2, zsh,
   Starship and direnv through Homebrew, and Ghostty through its cask
   if absent. Obtain the full compatible Xcode required by the current
   formula through Apple's supported installation route; Command Line
   Tools alone are insufficient. Start the available installation steps
   and resume after any Apple sign-in, administrator or licence prompt
   I must complete. Check the selected Xcode and Swift before building.
   Do not replace existing terminal themes, fonts or the account's
   default shell. Do not install Granted unless I selected it.

4. Review the current formula, then run:
   brew tap stephenlclarke/tap
   brew install --HEAD stephenlclarke/tap/aws-auto-approve
   If already installed, use:
   brew upgrade --fetch-HEAD stephenlclarke/tap/aws-auto-approve
   Keep integrations on Homebrew's stable bin paths, not Cellar paths.
   Detect older helper commands shadowing them and preserve backups
   before moving only the obsolete entries aside.

5. Make Homebrew commands available in the actual zsh login startup
   file. Use the existing completion framework and add Homebrew's
   zsh completion directory to fpath before compinit if missing.
   Initialise Starship once, then the direnv zsh hook once. Preserve
   the existing prompt layout. Ensure its AWS module is enabled and
   included through $aws or $all so it can show AWS_PROFILE. Use plain
   symbols if the existing font lacks the required glyphs. If Ghostty
   does not already start zsh as a login shell, configure it to use
   the detected zsh executable with --login. Respect Ghostty's active
   config location and included files; do not overwrite its other settings.

6. Without Granted: use standard AWS CLI IAM Identity Center profiles
   and aws-auto-approve-login. Keep existing working profiles. If a
   selected profile uses Granted's credential_process, back it up and
   migrate only that profile to standard AWS CLI SSO configuration;
   do not leave a hidden Granted dependency. Use aws configure sso
   when needed, with my organisation's settings. Leave unrelated
   Granted installations and profiles unchanged.

7. With Granted: install it if missing using the current official guide:
   https://docs.granted.dev/getting-started/
   Its current managed Homebrew route is:
   brew tap fwdcloudsec/granted
   brew install fwdcloudsec/granted/granted
   Configure Granted's zsh assume alias and completion once, using
   detected executable paths and its official shell setup. Back up
   ~/.granted/config. Set top-level CustomSSOBrowserPath to the absolute
   Homebrew aws-auto-approve executable, without arguments. An existing
   SSOBrowserLaunchTemplate overrides it: remove only that SSO template
   when switching, preserving console browser settings and other templates.
   Keep suitable AWS profiles. For AWS CLI/direnv access through Granted,
   configure only selected profiles using its credential-process guide:
   https://docs.granted.dev/recipes/credential-process/
   Respect its granted_sso_* key requirements; do not merely add a
   credential_process alongside standard SSO keys that take precedence.
   Never run a credential-process command directly into visible output.

8. Configure only my selected project directories. Keep local .envrc
   files out of Git using the repository's existing ignore rules or
   .git/info/exclude. Preserve unrelated .envrc content. Without Granted,
   use one line per profile in my chosen order:
   aws-auto-approve-login --if-needed PROFILE || return
   Then export AWS_PROFILE as the intended final profile. Substitute
   the real names; never write PROFILE as a literal placeholder.
   With Granted, use GRANTED_ALIAS_CONFIGURED=true and the absolute
   assume executable with PROFILE --exec true || return to warm roles,
   rather than sourcing the interactive assume alias into direnv. Then set
   AWS_PROFILE to the selected credential-process profile so CLI tools
   can retrieve credentials from Granted. Review the complete resulting
   .envrc before running direnv allow in each selected directory.

9. Validate both installed commands' --help output, brew test and the
   app signature. Check changed zsh files with zsh -n. In a fresh
   Ghostty login shell, verify command resolution and completions,
   Starship and the direnv hook. Test a real sign-in using the selected
   route, then verify STS role access without printing identity data.
   Without Granted, also test --if-needed and its profile-ready status.
   With Granted, test assume and AWS CLI access through the selected
   credential-process profile. Enter and leave each configured project:
   confirm profiles are checked in order, AWS_PROFILE and the prompt
   show the final profile, and direnv restores the previous environment
   on exit. Let me complete credentials, DUO or other MFA in the app.
   A cached-session check alone does not prove browser approval works.

10. Never enable shell tracing, dump the environment, record credentials
    or authentication URLs/codes, or pipe direnv export zsh into the app.
    Do not copy AWS caches, WebKit cookies or keychain data from another
    Mac. Do not disable TLS checks or macOS security to fix installation
    errors. Report a blocked dependency or test accurately and continue
    independent work. Finish with the chosen route, installed versions,
    changed files and backup locations, validation results, rollback
    steps and any exact action still needed from me.
````

### Why there are two commands

- `aws-auto-approve` is the native Swift/WebKit app. It receives an authorisation URL or authentication messages, handles supported AWS approval pages and shows a window for login or MFA. Granted calls this command directly. It does not fetch AWS role credentials.
- `aws-auto-approve-login` is the shell wrapper for AWS CLI. It starts sign-in for a profile, streams the request to the native app, handles cancellation and failures, then verifies role access through STS. Its `--if-needed` option reuses a valid session. Use this command from zsh and direnv when working without Granted.

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
