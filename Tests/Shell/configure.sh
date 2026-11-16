#!/usr/bin/env bash
# USAGE: configure.sh - test setup in private temporary homes with stubbed installers.
# shellcheck disable=SC2016 # Tests assert literal shell/TOML expansions.
set -euo pipefail
unset BASH_ENV ENV
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Build a synthetic home and replace every installer/authentication command.
fixture() {
    unset SCRIPT_COLOUR NO_COLOR
    export HOME="$CASE_ROOT/home" XDG_CONFIG_HOME="$CASE_ROOT/home/.config"
    export ZDOTDIR="$HOME" STARSHIP_CONFIG="$HOME/.config/starship.toml"
    export AWS_CONFIG_FILE="$HOME/.aws/config" TEST_CALLS="$CASE_ROOT/calls"
    mkdir -p "$HOME/.aws" "$CASE_ROOT/bin" "$CASE_ROOT/work" "$CASE_ROOT/project" "$CASE_ROOT/prefix/bin"
    export PATH="$CASE_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    cat >"$CASE_ROOT/bin/brew" <<'STUB'
#!/bin/bash
printf 'brew %s\n' "$*" >>"$TEST_CALLS"
case "$1" in
    --prefix) printf '%s/prefix\n' "$CASE_ROOT" ;;
    list) [[ "${TEST_MISSING:-}" != "${*: -1}" ]] ;;
    test) exit "${TEST_BREW_FAILURE:-0}" ;;
    install) exit "${TEST_INSTALL_FAILURE:-0}" ;;
esac
STUB
    cat >"$CASE_ROOT/bin/granted" <<'STUB'
#!/bin/bash
exit "${TEST_GRANTED_FAILURE:-0}"
STUB
    cat >"$CASE_ROOT/bin/xcode-select" <<'STUB'
#!/bin/bash
printf '/Applications/Fixture.app/Contents/Developer\n'
STUB
    cat >"$CASE_ROOT/bin/xcrun" <<'STUB'
#!/bin/bash
printf 'Apple Swift version 6.0\n'
STUB
    cat >"$CASE_ROOT/bin/starship" <<'STUB'
#!/bin/bash
if [[ "$1" == print-config ]]; then
    if [[ "${TEST_STARSHIP_FAILURE:-0}" == 1 ]]; then printf 'fixture parse error\n' >&2; exit 1; fi
    cat "$STARSHIP_CONFIG"
else
    printf 'prompt_starship_precmd() { :; }\n'
fi
STUB
    cat >"$CASE_ROOT/bin/codesign" <<'STUB'
#!/bin/bash
exit "${TEST_SIGNATURE_FAILURE:-0}"
STUB
    cat >"$CASE_ROOT/bin/direnv" <<'STUB'
#!/bin/bash
printf 'direnv %s\n' "$*" >>"$TEST_CALLS"
if [[ "$1" == hook ]]; then printf '_direnv_hook() { :; }\n'; fi
STUB
    cat >"$CASE_ROOT/bin/aws" <<'STUB'
#!/bin/bash
printf 'aws %s\n' "$*" >>"$TEST_CALLS"
exit "${TEST_STS_FAILURE:-0}"
STUB
    cat >"$CASE_ROOT/prefix/bin/aws-auto-approve" <<'STUB'
#!/bin/bash
[[ "$1" == --help ]]
STUB
    cat >"$CASE_ROOT/prefix/bin/aws-auto-approve-login" <<'STUB'
#!/bin/bash
printf 'login %s\n' "$*" >>"$TEST_CALLS"
STUB
    cat >"$CASE_ROOT/bin/ghostty" <<'STUB'
#!/bin/bash
exit 0
STUB
    cat >"$CASE_ROOT/bin/assume" <<'STUB'
#!/bin/bash
printf 'assume %s\n' "$*" >>"$TEST_CALLS"
exit "${TEST_ASSUME_FAILURE:-0}"
STUB
    chmod +x "$CASE_ROOT/bin/"* "$CASE_ROOT/prefix/bin/"*
    local command
    for command in brew granted assume starship direnv aws ghostty; do
        ln -s "$CASE_ROOT/bin/$command" "$CASE_ROOT/prefix/bin/$command"
    done
    export PATH="$CASE_ROOT/prefix/bin:$PATH"
    cat >"$AWS_CONFIG_FILE" <<'INI'
[profile alpha]
sso_start_url = https://fixture.awsapps.com/start
sso_region = eu-west-1
sso_account_id = 123456789012
sso_role_name = ReadOnly
region = eu-west-1

[profile other]
credential_process = unrelated-provider
INI
    # shellcheck source=configure.sh
    source "$ROOT/configure.sh"
    WORK_DIR="$CASE_ROOT/work"
    BREW="$CASE_ROOT/bin/brew"
    BREW_PREFIX="$CASE_ROOT/prefix"
    CONFIG_AWS="$AWS_CONFIG_FILE"
    CONFIG_ZDOTDIR="$HOME"
    GRANTED="$CASE_ROOT/bin/granted"
    MODE=without-granted
}

# Check auto-detection offers the working existing installation by default.
detected_default() {
    MODE=''; DRY_RUN=1
    choose_mode
    [[ "$MODE" == with-granted ]]
}

# A broken installation must not become the recommended route.
broken_default() {
    export TEST_GRANTED_FAILURE=1
    MODE=''; DRY_RUN=1
    choose_mode
    [[ "$MODE" == without-granted ]]
}

# Explicit AWS CLI selection takes priority over installed Granted.
explicit_mode() {
    choose_mode
    [[ "$MODE" == without-granted ]]
}

# Retain separate warm-up orders and final profile selections for each project.
project_arguments() {
    PROJECTS=(); PROFILES=(); MODE=''
    parse_args --without-granted --project "$CASE_ROOT/project" --profile alpha --profile beta --active-profile alpha \
        --project "$HOME" --profile gamma
    [[ "${PROJECT_PROFILES[0]}" == 'alpha beta ' && "${PROJECT_ACTIVE[0]}" == alpha ]]
    [[ "${PROJECT_PROFILES[1]}" == 'gamma ' && "${PROJECT_ACTIVE[1]}" == gamma ]]
}

# Preserve symlinks, unrelated content and permissions, and back up original data once.
managed_backups() {
    printf 'keep me\n' >"$HOME/real file"
    chmod 640 "$HOME/real file"
    ln -s 'real file' "$HOME/link"
    printf 'managed\n' >"$WORK_DIR/block"
    managed_block "$HOME/link" fixture "$WORK_DIR/block"
    [[ -L "$HOME/link" ]]
    grep -Fxq 'keep me' "$HOME/real file"
    grep -Fxq 'keep me' "$BACKUP_DIR/0"
    [[ "$(stat -f '%Lp' "$HOME/real file")" == 640 ]]
    cp "$HOME/real file" "$WORK_DIR/first"
    managed_block "$HOME/link" fixture "$WORK_DIR/block"
    cmp "$HOME/real file" "$WORK_DIR/first"
    [[ ${#CHANGED_FILES[@]} == 1 ]]
}

# An incomplete managed block must never cause the rest of a file to be removed.
reject_bad_block() {
    printf 'keep\n# >>> aws-auto-approve fixture >>>\n' >"$HOME/rc"
    printf 'new\n' >"$WORK_DIR/block"
    cp "$HOME/rc" "$WORK_DIR/before"
    local status=0
    (managed_block "$HOME/rc" fixture "$WORK_DIR/block") || status=$?
    [[ "$status" == 1 ]]
    cmp "$HOME/rc" "$WORK_DIR/before"
}

# Standard AWS CLI profiles do not need a provider rewrite.
preserve_cli_profile() {
    cp "$AWS_CONFIG_FILE" "$WORK_DIR/before"
    configure_profile alpha
    cmp "$AWS_CONFIG_FILE" "$WORK_DIR/before"
}

# Convert shared-session SSO to Granted and leave the shared session and other profile intact.
granted_profile() {
    cat >"$AWS_CONFIG_FILE" <<'INI'
[profile alpha]
sso_session = shared
sso_account_id = 123456789012
sso_role_name = ReadOnly
region = eu-west-1
[sso-session shared]
sso_start_url = https://fixture.awsapps.com/start
sso_region = eu-west-1
sso_registration_scopes = sso:account:access
[profile other]
credential_process = unrelated-provider
INI
    MODE=with-granted
    configure_profile alpha
    [[ "$(ini_get "$AWS_CONFIG_FILE" 'profile alpha' granted_sso_region)" == eu-west-1 ]]
    [[ -z "$(ini_get "$AWS_CONFIG_FILE" 'profile alpha' sso_session)" ]]
    [[ "$(ini_get "$AWS_CONFIG_FILE" 'sso-session shared' sso_region)" == eu-west-1 ]]
    [[ "$(ini_get "$AWS_CONFIG_FILE" 'profile other' credential_process)" == unrelated-provider ]]
    grep -Fq 'credential-process --auto-login --profile alpha' "$AWS_CONFIG_FILE"
    MODE=without-granted
    configure_profile alpha
    [[ "$(ini_get "$AWS_CONFIG_FILE" 'profile alpha' sso_region)" == eu-west-1 ]]
    [[ -z "$(ini_get "$AWS_CONFIG_FILE" 'profile alpha' credential_process)" ]]
}

# Refuse to replace an unrelated provider in a selected profile.
reject_provider() {
    local status=0
    cp "$AWS_CONFIG_FILE" "$WORK_DIR/before"
    (configure_profile other) || status=$?
    [[ "$status" == 1 ]]
    cmp "$AWS_CONFIG_FILE" "$WORK_DIR/before"
}

# Fresh machines can create SSO profile definitions without running an unfiltered login.
new_profile() {
    ensure_profile_settings beta <<'INPUT'
https://fixture.awsapps.com/start
eu-west-1
123456789012
ReadOnly
INPUT
    [[ "$(ini_get "$AWS_CONFIG_FILE" 'profile beta' sso_role_name)" == ReadOnly ]]
    [[ "$(ini_get "$AWS_CONFIG_FILE" 'profile alpha' sso_role_name)" == ReadOnly ]]
}

# Only Granted's SSO browser template is superseded.
granted_browser() {
    mkdir -p "$HOME/.granted"
    cat >"$HOME/.granted/config" <<'TOML'
CustomSSOBrowserPath = "/old/helper"
DefaultBrowser = "Safari"
[SSOBrowserLaunchTemplate]
Command = "old-browser"
[BrowserLaunchTemplate]
Command = "keep-browser"
TOML
    configure_granted
    grep -Fq 'DefaultBrowser = "Safari"' "$HOME/.granted/config"
    grep -Fq 'Command = "keep-browser"' "$HOME/.granted/config"
    if grep -Fq 'old-browser' "$HOME/.granted/config"; then return 1; fi
    [[ $(grep -c '^CustomSSOBrowserPath' "$HOME/.granted/config") == 1 ]]
}

# Do not duplicate the AWS module already present in a multiline prompt format.
starship_multiline() {
    mkdir -p "$HOME/.config"
    cat >"$STARSHIP_CONFIG" <<'TOML'
format = """
$directory$aws$line_break$character"""
palette = 'my_palette'
[aws]
disabled = true
format = 'AWS $profile'
[directory]
style = 'green'
TOML
    configure_starship
    [[ $(grep -o '\$aws' "$STARSHIP_CONFIG" | wc -l | tr -d ' ') == 1 ]]
    grep -Fxq "style = 'green'" "$STARSHIP_CONFIG"
    grep -Fxq 'disabled = false' "$STARSHIP_CONFIG"
    cp "$STARSHIP_CONFIG" "$WORK_DIR/before"
    configure_starship
    cmp "$STARSHIP_CONFIG" "$WORK_DIR/before"
}

# Add AWS to a custom prompt that omits it without replacing the theme.
starship_missing_module() {
    mkdir -p "$HOME/.config"
    printf "format = '\$directory\$character'\n" >"$STARSHIP_CONFIG"
    configure_starship
    grep -Fq '$aws' "$STARSHIP_CONFIG"
}

# Reject a proposed prompt configuration before touching the user's original.
starship_failure() {
    local status=0
    mkdir -p "$HOME/.config"
    printf 'format = "$all"\n' >"$STARSHIP_CONFIG"
    cp "$STARSHIP_CONFIG" "$WORK_DIR/before"
    export TEST_STARSHIP_FAILURE=1
    (configure_starship) || status=$?
    [[ "$status" == 1 ]]
    cmp "$STARSHIP_CONFIG" "$WORK_DIR/before"
}

# Put completion paths before an existing compinit and guard existing prompt hooks.
shell_blocks() {
    printf 'autoload -Uz compinit\ncompinit\n# keep my aliases\n' >"$HOME/.zshrc"
    configure_zsh
    /bin/zsh -n "$HOME/.zshrc" "$HOME/.zprofile"
    [[ "$(head -1 "$HOME/.zshrc")" == '# >>> aws-auto-approve completions >>>' ]]
    grep -Fq '# keep my aliases' "$HOME/.zshrc"
    cp "$HOME/.zshrc" "$WORK_DIR/before"
    configure_zsh
    cmp "$HOME/.zshrc" "$WORK_DIR/before"
}

# Keep native Ghostty config and appearance while updating the launch shell.
ghostty_preserves_theme() {
    local file="$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
    mkdir -p "$(dirname "$file")"
    printf 'theme = custom\nfont-size = 14\n' >"$file"
    configure_ghostty
    grep -Fxq 'theme = custom' "$file"
    grep -Fq -- '--login' "$HOME/.config/aws-auto-approve/ghostty.conf"
    grep -Fq 'config-file = ' "$file"
    [[ ! -f "$HOME/.config/ghostty/config" ]]
}

# Migrate the prior documented envrc without keeping duplicate authentication calls.
project_migration() {
    git -C "$CASE_ROOT/project" init -q
    printf 'export KEEP_ME=1\naws-auto-approve-login --if-needed alpha || return\nexport AWS_PROFILE=alpha\n' >"$CASE_ROOT/project/.envrc"
    PROJECTS=("$CASE_ROOT/project"); PROJECT_PROFILES=('alpha '); PROJECT_ACTIVE=(alpha)
    configure_project 0 <<<'y'
    grep -Fxq 'export KEEP_ME=1' "$CASE_ROOT/project/.envrc"
    [[ $(grep -c '^aws-auto-approve-login' "$CASE_ROOT/project/.envrc") == 1 ]]
    git -C "$CASE_ROOT/project" check-ignore -q .envrc
    grep -Fq 'direnv allow .' "$TEST_CALLS"
    cp "$CASE_ROOT/project/.envrc" "$WORK_DIR/first-envrc"
    configure_project 0 <<<'y'
    cmp "$CASE_ROOT/project/.envrc" "$WORK_DIR/first-envrc"
    # Exported credentials from a previous interactive role must not override this profile.
    export AWS_ACCESS_KEY_ID=fixture AWS_SECRET_ACCESS_KEY=fixture AWS_SESSION_TOKEN=fixture
    # shellcheck disable=SC1091 # Source only the synthetic envrc built in this test.
    source "$CASE_ROOT/project/.envrc"
    [[ -z "${AWS_ACCESS_KEY_ID+x}" && -z "${AWS_SECRET_ACCESS_KEY+x}" && -z "${AWS_SESSION_TOKEN+x}" && "$AWS_PROFILE" == alpha ]]
}

# Owned blocks must not hide a second unmanaged authentication command added later.
project_unmanaged_conflict() {
    local status=0
    PROJECTS=("$CASE_ROOT/project"); PROJECT_PROFILES=('alpha '); PROJECT_ACTIVE=(alpha)
    configure_project 0 <<<'y'
    printf 'assume other-role\n' >>"$CASE_ROOT/project/.envrc"
    cp "$CASE_ROOT/project/.envrc" "$WORK_DIR/before-conflict"
    (configure_project 0 <<<'y') || status=$?
    [[ "$status" == 1 ]]
    cmp "$CASE_ROOT/project/.envrc" "$WORK_DIR/before-conflict"
}

# Never change a tracked envrc into a private per-user setup.
tracked_project() {
    local status=0
    git -C "$CASE_ROOT/project" init -q
    printf 'export KEEP_ME=1\n' >"$CASE_ROOT/project/.envrc"
    git -C "$CASE_ROOT/project" add .envrc
    PROJECTS=("$CASE_ROOT/project"); PROJECT_PROFILES=('alpha '); PROJECT_ACTIVE=(alpha)
    (configure_project 0 <<<'y') || status=$?
    [[ "$status" == 1 ]]
    if grep -Fq 'AWS_PROFILE' "$CASE_ROOT/project/.envrc"; then return 1; fi
}

# A failed signature must stop setup even when the caller collects validation status.
signature_failure() {
    local status=0
    export TEST_SIGNATURE_FAILURE=7
    (validate_installation) || status=$?
    [[ "$status" == 1 ]]
    if [[ -f "$TEST_CALLS" ]] && grep -Fq 'login alpha' "$TEST_CALLS"; then return 1; fi
}

# Complete the command's real orchestration against isolated installer and auth stubs.
complete_setup() {
    printf '\ny\n' | bash "$ROOT/configure.sh" --without-granted --profile alpha >"$WORK_DIR/output" 2>&1 || { cat "$WORK_DIR/output"; return 1; }
    grep -Fq 'Configured route: without-granted' "$WORK_DIR/output"
    grep -Fq 'login alpha' "$TEST_CALLS"
    grep -Fq 'login --if-needed alpha' "$TEST_CALLS"
    grep -Fq 'aws sts get-caller-identity --profile alpha' "$TEST_CALLS"
    [[ -f "$HOME/.zshrc" && -f "$STARSHIP_CONFIG" ]]
}

# Granted's complete route installs only its missing dependency and verifies the provider.
complete_granted_setup() {
    export TEST_MISSING=fwdcloudsec/granted/granted
    printf '\ny\n' | bash "$ROOT/configure.sh" --with-granted --profile alpha >"$WORK_DIR/output" 2>&1 || { cat "$WORK_DIR/output"; return 1; }
    grep -Fq 'Configured route: with-granted' "$WORK_DIR/output"
    grep -Fq 'assume alpha --exec true' "$TEST_CALLS"
    grep -Fq 'credential-process --auto-login --profile alpha' "$AWS_CONFIG_FILE"
    if grep -Fq 'login alpha' "$TEST_CALLS"; then return 1; fi
}

# A failed formula test remains a failed run even after other checks succeed.
failed_formula_test() {
    local status=0
    export TEST_BREW_FAILURE=8
    printf '\ny\n' | bash "$ROOT/configure.sh" --without-granted --profile alpha >"$WORK_DIR/output" 2>&1 || status=$?
    [[ "$status" == 1 ]]
    grep -Fq 'Verified profile: alpha' "$WORK_DIR/output"
}

# Skipping login must not authorise a directory that could trigger it on the next prompt.
skip_login() {
    PROJECTS=("$CASE_ROOT/project"); PROJECT_PROFILES=('alpha '); PROJECT_ACTIVE=(alpha)
    SKIP_LOGIN=1
    configure_project 0 <<<'y'
    [[ -f "$CASE_ROOT/project/.envrc" ]]
    if [[ -f "$TEST_CALLS" ]] && grep -Fq 'direnv allow' "$TEST_CALLS"; then return 1; fi
}

# Explicit falsey/true colour overrides match the reference ~/bin scripts.
colour_overrides() {
    SCRIPT_COLOUR=off init_colours
    [[ -z "$RED" ]]
    SCRIPT_COLOUR=1 init_colours
    [[ -n "$RED" ]]
    NO_COLOR=1 SCRIPT_COLOUR=1 init_colours
    [[ -z "$RED" ]]
}

# A failed dependency must stop the real command before it edits configuration.
failed_dependency() {
    local status=0
    export TEST_MISSING=awscli TEST_INSTALL_FAILURE=8
    printf '\ny\n' | bash "$ROOT/configure.sh" --without-granted --profile alpha >"$WORK_DIR/output" 2>&1 || status=$?
    [[ "$status" == 1 && ! -f "$HOME/.zshrc" ]]
    grep -Fq 'Could not install awscli.' "$WORK_DIR/output"
}

# The missing-Granted branch uses the managed tap, not a second manual installation.
missing_granted_dependency() {
    MODE=with-granted; GRANTED=''
    export TEST_MISSING=fwdcloudsec/granted/granted
    install_dependencies
    grep -Fq 'brew tap fwdcloudsec/granted' "$TEST_CALLS"
    grep -Fq 'brew install fwdcloudsec/granted/granted' "$TEST_CALLS"
}

# Argument errors and help must not install anything or inspect authentication state.
cli_contract() {
    local status=0
    bash "$ROOT/configure.sh" --bogus >/dev/null 2>&1 || status=$?
    [[ "$status" == 2 ]]
    bash "$ROOT/configure.sh" --help | grep -Fq 'EXIT STATUS:'
    [[ ! -f "$TEST_CALLS" ]]
}

# A dry run must not create shell settings, credentials or backup directories.
dry_run() {
    bash "$ROOT/configure.sh" --without-granted --dry-run >"$WORK_DIR/output"
    [[ ! -f "$HOME/.zshrc" && ! -d "$HOME/Library" ]]
    ! grep -Eq '^brew (install|upgrade|tap)|^login ' "$TEST_CALLS"
}

if [[ "${1:-}" == --case ]]; then
    fixture
    "$2"
    exit 0
fi

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
COUNT=0
for test_case in detected_default broken_default explicit_mode project_arguments managed_backups reject_bad_block \
    preserve_cli_profile granted_profile reject_provider new_profile granted_browser starship_multiline \
    starship_missing_module starship_failure shell_blocks ghostty_preserves_theme project_migration project_unmanaged_conflict tracked_project \
    signature_failure complete_setup complete_granted_setup failed_formula_test failed_dependency missing_granted_dependency \
    skip_login colour_overrides cli_contract dry_run; do
    export CASE_ROOT="$TEST_ROOT/$test_case"
    mkdir -p "$CASE_ROOT"
    if ! bash "${BASH_SOURCE[0]}" --case "$test_case" >"$CASE_ROOT/output" 2>&1; then
        printf 'Configure test failed: %s\n' "$test_case" >&2
        cat "$CASE_ROOT/output" >&2
        exit 1
    fi
    ((COUNT += 1))
done
printf 'Configure integration: %s checks passed.\n' "$COUNT"
