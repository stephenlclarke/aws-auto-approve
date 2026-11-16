#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# USAGE:
#   Usage: @SCRIPT_NAME@ [OPTIONS]
#
# DESCRIPTION:
#   Install AWS Auto Approve and configure zsh, Ghostty, Starship and direnv.
#
# DETAILS:
#   Detects Granted and offers it as the default when it works. Installs
#   missing dependencies, backs up changed files and preserves other settings.
#   Apple sign-in, administrator approval, Xcode licences and MFA stay manual.
#   Run without options for guided setup. Re-running updates managed blocks.
#
# OPTIONS:
#   --with-granted          Use Granted; install it if missing.
#   --without-granted       Use AWS CLI directly; leave Granted installed.
#   --profile NAME          Select a profile; repeat in warm-up order.
#                          After --project, applies to that project too.
#   --project DIRECTORY     Configure an existing project; repeat for more.
#   --active-profile NAME   Final profile for the preceding project.
#                          Defaults to its last --profile.
#   --dry-run               Show the plan without changing files or signing in.
#   --skip-login            Configure but skip live authentication checks.
#   -h, --help              Show this help text and exit.
#
# ENVIRONMENT:
#   SCRIPT_COLOUR          0, false or off disables colour; other explicit
#                          values enable it. Default: stderr terminal only.
#                          NO_COLOR always disables colour.
#   ZDOTDIR                Zsh startup directory; otherwise detected from zsh.
#   STARSHIP_CONFIG        Starship configuration file, if set.
#   AWS_CONFIG_FILE        AWS configuration file, if set.
#   XDG_CONFIG_HOME        XDG configuration directory, if set.
#
# EXIT STATUS:
#   0    Setup completed, a dry run completed, or help was shown.
#   1    Setup failed or was cancelled; inspect the reported backups.
#   2    An unsupported or invalid argument was supplied.
# ENDUSAGE
# ---------------------------------------------------------------------------

set -euo pipefail

readonly SELF_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_NAME="$(basename "$SELF_PATH")"
readonly SCRIPT_NAME
MODE=''
DRY_RUN=0
SKIP_LOGIN=0
BREW=''
BREW_PREFIX=''
GRANTED=''
CONFIG_ZDOTDIR="${ZDOTDIR:-}"
CONFIG_AWS="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
PROFILES=()
PROJECTS=()
PROJECT_PROFILES=()
PROJECT_ACTIVE=()
CHANGED_FILES=()
WORK_DIR=''
BACKUP_DIR=''
RESET=''
GREEN=''
YELLOW=''
RED=''

# Print the embedded command usage with the actual script name.
usage() {
    awk -v script_name="$SCRIPT_NAME" '
        /^# USAGE:/ { printing = 1; next }
        printing && /^# ENDUSAGE/ { exit }
        printing { sub(/^#[ ]?/, ""); gsub(/@SCRIPT_NAME@/, script_name); print }
    ' "$SELF_PATH"
}

# Initialise colour once, respecting terminal and user overrides.
init_colours() {
    local use_colour=0
    RESET=''; GREEN=''; YELLOW=''; RED=''
    [[ -z "${NO_COLOR+x}" ]] || return 0
    case "${SCRIPT_COLOUR:-}" in
        0|false|FALSE|False|off|OFF|Off) return 0 ;;
        ''|auto) if [[ -t 2 && "${TERM:-}" != dumb ]]; then use_colour=1; fi ;;
        *) use_colour=1 ;;
    esac
    if ((use_colour)); then
        RESET=$'\033[0m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
    fi
}

# Print an informational message.
info() { printf '%s[i] %s%s\n' "$GREEN" "$*" "$RESET"; }

# Print a warning without exposing command output or configuration values.
warning() { printf '%s[!] %s%s\n' "$YELLOW" "$*" "$RESET" >&2; }

# Print an error and stop; existing backups remain available.
error() { printf '%s[x] %s%s\n' "$RED" "$*" "$RESET" >&2; exit 1; }

# Require a command before using it.
need() { command -v "$1" >/dev/null 2>&1 || error "Required command not found: $1"; }

# Reject invalid arguments with the conventional usage exit status.
bad_args() { warning "$*"; usage >&2; exit 2; }

# Read one response without mixing prompts with captured output.
ask() {
    printf '%s ' "$1" >&2
    IFS= read -r REPLY || error 'Input ended. Re-run interactively or supply the documented options.'
}

# Require an explicit yes for a consequential setup decision.
confirm() {
    ask "$1 [y/N]"
    case "$REPLY" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# Keep profile names safe for generated AWS sections and shell commands.
check_profile_name() {
    [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9._@+-]*$ ]] || error 'Profile names must use letters, digits, dots, underscores, @, + or -.'
}

# Select a profile once globally and retain its project-specific order.
add_profile() {
    local profile="$1" existing index
    check_profile_name "$profile"
    for existing in ${PROFILES[@]+"${PROFILES[@]}"}; do
        [[ "$existing" != "$profile" ]] || break
    done
    if [[ "${existing:-}" != "$profile" ]]; then PROFILES+=("$profile"); fi
    if ((${#PROJECTS[@]} > 0)); then
        index=$((${#PROJECTS[@]} - 1))
        PROJECT_PROFILES[index]="${PROJECT_PROFILES[$index]:-}${profile} "
        PROJECT_ACTIVE[index]="$profile"
    fi
}

# Parse grouped project/profile options; explicit modes bypass the route prompt.
parse_args() {
    while (($# > 0)); do
        case "$1" in
            --with-granted|--without-granted)
                [[ -z "$MODE" ]] || bad_args 'Choose only one authentication route.'
                MODE="${1#--}"; shift ;;
            --profile|--project|--active-profile)
                (($# >= 2)) && [[ -n "$2" && "$2" != -* ]] || bad_args "$1 needs a value."
                case "$1" in
                    --profile) add_profile "$2" ;;
                    --project)
                        [[ -d "$2" ]] || bad_args 'Project directory does not exist.'
                        PROJECTS+=("$(cd "$2" && pwd -P)")
                        PROJECT_PROFILES+=(''); PROJECT_ACTIVE+=('') ;;
                    --active-profile)
                        ((${#PROJECTS[@]} > 0)) || bad_args '--active-profile needs a preceding --project.'
                        check_profile_name "$2"
                        PROJECT_ACTIVE[${#PROJECTS[@]}-1]="$2" ;;
                esac
                shift 2 ;;
            --dry-run) DRY_RUN=1; shift ;;
            --skip-login) SKIP_LOGIN=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *) bad_args "Unknown argument: $1" ;;
        esac
    done
}

# Locate existing installations even when the invoking shell has an incomplete PATH.
detect_tools() {
    local candidate
    BREW="$(command -v brew || true)"
    if [[ -z "$BREW" ]]; then
        for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            if [[ -x "$candidate" ]]; then BREW="$candidate"; break; fi
        done
    fi
    if [[ -n "$BREW" ]]; then
        BREW_PREFIX="$("$BREW" --prefix)"
        export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"
    fi
    GRANTED="$(command -v granted || true)"
    if [[ -z "$GRANTED" ]]; then
        for candidate in /opt/homebrew/bin/granted /usr/local/bin/granted; do
            if [[ -x "$candidate" ]]; then GRANTED="$candidate"; break; fi
        done
    fi
}

# Offer the detected route, without treating a default as permission to proceed.
choose_mode() {
    local default_mode='without-granted'
    if [[ -n "$GRANTED" ]] && "$GRANTED" -v >/dev/null 2>&1; then
        default_mode='with-granted'
        info 'Granted is installed and working.'
    elif [[ -n "$GRANTED" ]]; then
        warning 'Granted is installed but its version check failed. The Granted route will attempt repair.'
    fi
    if [[ -n "$MODE" ]]; then return; fi
    if ((DRY_RUN)); then MODE="$default_mode"; return; fi
    info 'With Granted: role switching and the native helper as its SSO browser.'
    info 'Without Granted: the AWS CLI wrapper starts sign-in and checks role access.'
    ask "Use $default_mode? [Enter=yes, g=with Granted, a=AWS CLI, q=quit]"
    case "$REPLY" in
        '') MODE="$default_mode" ;;
        g|G) MODE='with-granted' ;;
        a|A) MODE='without-granted' ;;
        *) error 'Setup cancelled.' ;;
    esac
}

# Collect per-project profile choices when they were not supplied as options.
collect_projects() {
    local directory profile index
    local chosen=()
    if ((${#PROJECTS[@]} == 0)); then
        while :; do
            ask 'Project directory for automatic sign-in (blank when finished):'
            directory="$REPLY"
            [[ -n "$directory" ]] || break
            [[ -d "$directory" ]] || error 'Project directory does not exist.'
            PROJECTS+=("$(cd "$directory" && pwd -P)")
            PROJECT_PROFILES+=(''); PROJECT_ACTIVE+=('')
        done
    fi
    for ((index=0; index<${#PROJECTS[@]}; index++)); do
        if [[ -z "${PROJECT_PROFILES[$index]}" ]]; then
            ask "Profiles for ${PROJECTS[$index]}, in warm-up order (space-separated):"
            read -r -a chosen <<<"$REPLY"
            ((${#chosen[@]} > 0)) || error 'Select at least one profile per project.'
            for profile in "${chosen[@]}"; do
                check_profile_name "$profile"
                PROFILES+=("$profile")
                PROJECT_PROFILES[index]="${PROJECT_PROFILES[$index]}$profile "
            done
            PROJECT_ACTIVE[index]="${chosen[${#chosen[@]}-1]}"
            ask "Final active profile [${PROJECT_ACTIVE[$index]}]:"
            if [[ -n "$REPLY" ]]; then PROJECT_ACTIVE[index]="$REPLY"; fi
        fi
        case " ${PROJECT_PROFILES[$index]}" in
            *" ${PROJECT_ACTIVE[$index]} "*) ;;
            *) error "Each active profile must be in that project's warm-up list." ;;
        esac
    done
    if ((${#PROFILES[@]} == 0)); then
        ask 'AWS profile to configure and verify:'
        add_profile "$REPLY"
    fi
}

# Show the intended scope without reading secrets or running shell startup files.
show_plan() {
    local index
    info "Authentication route: $MODE"
    info "Homebrew: ${BREW:-install from brew.sh}"
    info 'Dependencies: full Xcode, AWS CLI v2, zsh, Ghostty, Starship and direnv.'
    info 'Existing themes, fonts, account default shell and unrelated AWS profiles are preserved.'
    if [[ "$MODE" == with-granted ]]; then info 'Install or reuse Granted and configure its SSO browser.'; fi
    for ((index=0; index<${#PROJECTS[@]}; index++)); do
        info "Project: ${PROJECTS[$index]}; profiles: ${PROJECT_PROFILES[$index]}; active: ${PROJECT_ACTIVE[$index]}"
    done
    if ((SKIP_LOGIN)); then warning 'Live sign-in verification was explicitly skipped.'; fi
}

# Remove only this invocation's private temporary data.
cleanup() {
    local status=$?
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then rm -rf "$WORK_DIR"; fi
    if ((status != 0)) && [[ -n "$BACKUP_DIR" ]]; then
        warning "Setup stopped after changes. Backups and rollback mapping: $BACKUP_DIR/manifest.txt"
    fi
}

# Resolve symlink targets so managed dot-file links remain intact.
resolve_file() {
    local file="$1" target count=0
    while [[ -L "$file" ]]; do
        ((count += 1)); ((count < 40)) || error 'Configuration symlink loop.'
        target="$(readlink "$file")"
        if [[ "$target" == /* ]]; then file="$target"; else file="$(dirname "$file")/$target"; fi
    done
    printf '%s\n' "$file"
}

# Save changed files once, then atomically replace their target with private content.
write_file() {
    local file source="$2" existing backup temporary
    file="$(resolve_file "$1")"
    if [[ -f "$file" ]] && cmp -s "$file" "$source"; then return; fi
    for existing in ${CHANGED_FILES[@]+"${CHANGED_FILES[@]}"}; do
        [[ "$existing" != "$file" ]] || break
    done
    if [[ "${existing:-}" != "$file" ]]; then
        if [[ -z "$BACKUP_DIR" ]]; then
            BACKUP_DIR="$HOME/Library/Application Support/AWSAutoApprove/configure-backups/$(date -u +%Y%m%dT%H%M%SZ)-$$"
            mkdir -p "$BACKUP_DIR"
        fi
        backup="$BACKUP_DIR/${#CHANGED_FILES[@]}"
        if [[ -e "$file" ]]; then
            cp -p "$file" "$backup"
            printf 'Restore %q from %q\n' "$file" "$backup" >>"$BACKUP_DIR/manifest.txt"
        else
            printf 'Created %q; remove only if unchanged since setup.\n' "$file" >>"$BACKUP_DIR/manifest.txt"
        fi
        CHANGED_FILES+=("$file")
    fi
    mkdir -p "$(dirname "$file")"
    temporary="$(mktemp "$(dirname "$file")/.aws-auto-approve.XXXXXX")"
    if [[ -f "$file" ]]; then cp -p "$file" "$temporary"; fi
    cat "$source" >"$temporary"
    mv -f "$temporary" "$file"
    info "Updated: $file"
}

# Replace a uniquely named managed block while keeping all unrelated text.
managed_block() {
    local file="$1" name="$2" content="$3" position="${4:-end}" input
    input="${5:-$(resolve_file "$file")}"
    [[ -f "$input" ]] || input=/dev/null
    awk -v begin="# >>> aws-auto-approve $name >>>" -v end="# <<< aws-auto-approve $name <<<" '
        $0 == begin { if (inside) exit 2; inside=1; next }
        $0 == end { if (!inside) exit 2; inside=0; next }
        !inside { print }
        END { if (inside) exit 2 }
    ' "$input" >"$WORK_DIR/unmanaged" || error 'Malformed managed configuration block; repair it before retrying.'
    {
        if [[ "$position" != start ]]; then cat "$WORK_DIR/unmanaged"; fi
        printf '# >>> aws-auto-approve %s >>>\n' "$name"
        cat "$content"
        printf '# <<< aws-auto-approve %s <<<\n' "$name"
        if [[ "$position" == start ]]; then cat "$WORK_DIR/unmanaged"; fi
    } >"$WORK_DIR/managed"
    write_file "$file" "$WORK_DIR/managed"
}

# Install a missing Homebrew formula without upgrading unrelated software.
install_formula() {
    if ! "$BREW" list --versions "$1" >/dev/null 2>&1; then
        info "Installing: $1"
        "$BREW" install "$1" || error "Could not install $1."
    fi
}

# Bootstrap Homebrew from its official source without piping a download into a shell.
ensure_homebrew() {
    if [[ -z "$BREW" ]]; then
        curl --fail --silent --show-error --location --proto '=https' \
            https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$WORK_DIR/homebrew-install.sh" || error 'Homebrew installer download failed.'
        /bin/bash "$WORK_DIR/homebrew-install.sh" || error 'Homebrew installation needs attention. Complete its prerequisites and re-run.'
        detect_tools
        [[ -n "$BREW" ]] || error 'Homebrew installation did not complete.'
    fi
    export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
}

# Install full Xcode if needed; leave Apple account and licence decisions to the user.
ensure_xcode() {
    local selected version
    selected="$(xcode-select -p 2>/dev/null || true)"
    if [[ "$selected" != *.app/Contents/Developer ]]; then
        if [[ ! -d /Applications/Xcode.app ]]; then
            install_formula mas
            info 'Installing Xcode through the Mac App Store. Apple sign-in or administrator approval may be required.'
            "$BREW_PREFIX/bin/mas" install 497799835 || error 'Xcode installation needs attention in the App Store. Complete it, then re-run.'
        fi
        sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer || error 'Could not select full Xcode.'
    fi
    version="$(xcrun --toolchain XcodeDefault swift --version 2>/dev/null || true)"
    [[ "$version" =~ Swift[[:space:]]version[[:space:]]([0-9]+) ]] || error 'Open Xcode, complete its licence and first launch, then re-run.'
    ((BASH_REMATCH[1] >= 6)) || error 'Xcode 16 / Swift 6 or later is required. Update Xcode, then re-run.'
}

# Install the selected dependencies and refresh the helper from the public tap.
install_dependencies() {
    local formula owner
    ensure_homebrew
    for formula in awscli zsh starship direnv; do install_formula "$formula"; done
    if [[ ! -d /Applications/Ghostty.app && ! -d "$HOME/Applications/Ghostty.app" ]] && ! command -v ghostty >/dev/null 2>&1; then
        "$BREW" install --cask ghostty || error 'Could not install Ghostty.'
    fi
    if [[ "$MODE" == with-granted ]]; then
        if [[ -z "$GRANTED" ]]; then
            "$BREW" tap fwdcloudsec/granted || error 'Could not add the Granted tap.'
            install_formula fwdcloudsec/granted/granted
        elif ! "$GRANTED" -v >/dev/null 2>&1; then
            owner="$("$BREW" list --formula --full-name | awk '/(^|\/)granted$/ { print; exit }')"
            [[ -n "$owner" && "$GRANTED" == "$BREW_PREFIX/bin/granted" ]] || error 'Repair the existing non-Homebrew Granted installation, then re-run; no duplicate was installed.'
            "$BREW" reinstall "$owner" || error 'Granted repair failed.'
            "$GRANTED" -v >/dev/null 2>&1 || error 'Granted repair did not complete.'
        fi
        GRANTED="$(command -v granted)"
        [[ -x "${GRANTED%/*}/assume" ]] || error 'Granted is missing its companion assume executable. Repair that installation first.'
    fi
    ensure_xcode
    "$BREW" tap stephenlclarke/tap || error 'Could not add the AWS Auto Approve tap.'
    if "$BREW" list --versions stephenlclarke/tap/aws-auto-approve >/dev/null 2>&1; then
        "$BREW" upgrade --fetch-HEAD stephenlclarke/tap/aws-auto-approve || error 'AWS Auto Approve upgrade failed.'
    else
        "$BREW" install --HEAD stephenlclarke/tap/aws-auto-approve || error 'AWS Auto Approve installation failed.'
    fi
}

# Read one selected INI key, never displaying credentials or entire configuration files.
ini_get() {
    local file="$1" section="$2" key="$3"
    [[ -f "$file" ]] || return 0
    awk -v section="[$section]" -v key="$key" '
        /^[[:space:]]*\[/ { line=$0; sub(/^[[:space:]]*/, "", line); sub(/[[:space:]]*$/, "", line); inside=(line==section) }
        inside && /^[[:space:]]*[^#;][^=]*=/ {
            name=$0; sub(/=.*/, "", name); gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
            if (name==key) { sub(/^[^=]*=[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit }
        }
    ' "$file"
}

# Change only the selected profile's SSO provider; preserve shared sessions and other keys.
configure_profile() {
    local profile="$1" section="profile $1" session provider key value found count
    [[ "$profile" != default ]] || section=default
    provider="$(ini_get "$CONFIG_AWS" "$section" credential_process)"
    if [[ -n "$provider" && "$provider" != *'granted credential-process'* && "$provider" != *'granted" credential-process'* ]]; then
        error "Profile $profile has an unrelated credential provider. It was left unchanged."
    fi
    session="$(ini_get "$CONFIG_AWS" "$section" sso_session)"
    : >"$WORK_DIR/profile-keys"
    for key in sso_start_url sso_region sso_account_id sso_role_name sso_registration_scopes; do
        value="$(ini_get "$CONFIG_AWS" "$section" "$key")"
        if [[ -z "$value" ]]; then value="$(ini_get "$CONFIG_AWS" "$section" "granted_$key")"; fi
        if [[ -z "$value" && -n "$session" ]]; then value="$(ini_get "$CONFIG_AWS" "sso-session $session" "$key")"; fi
        if [[ "$key" != sso_registration_scopes && -z "$value" ]]; then
            error "Profile $profile is incomplete; no provider change was made."
        fi
        [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || error 'Multiline SSO values are not supported.'
        if [[ -n "$value" ]]; then
            if [[ "$MODE" == with-granted ]]; then printf 'granted_%s = %s\n' "$key" "$value"; else printf '%s = %s\n' "$key" "$value"; fi
        fi
    done >"$WORK_DIR/profile-keys"
    if [[ "$MODE" == with-granted ]]; then
        printf 'credential_process = "%s" credential-process --auto-login --profile %s\n' "$GRANTED" "$profile" >>"$WORK_DIR/profile-keys"
    elif [[ -z "$provider" && -z "$(ini_get "$CONFIG_AWS" "$section" granted_sso_start_url)" ]]; then
        return
    fi
    found="$(resolve_file "$CONFIG_AWS")"
    count="$(awk -v section="[$section]" '$0==section { count++ } END { print count+0 }' "$found")"
    [[ "$count" == 1 ]] || error "Profile $profile must have exactly one unindented section header. No profile was changed."
    awk -v section="[$section]" -v keys="$WORK_DIR/profile-keys" '
        function emit( line) { while ((getline line < keys)>0) print line; close(keys) }
        /^\[/ { if (inside) emit(); inside=($0==section) }
        inside && /^[[:space:]]*(granted_)?sso_[A-Za-z_]+[[:space:]]*=/ { next }
        inside && /^[[:space:]]*credential_process[[:space:]]*=/ { next }
        { print }
        END { if (inside) emit() }
    ' "$found" >"$WORK_DIR/aws-config"
    write_file "$CONFIG_AWS" "$WORK_DIR/aws-config"
}

# Create missing SSO settings interactively without starting an unfiltered browser login.
ensure_profile_settings() {
    local profile="$1" section="profile $1" key value session original
    [[ "$profile" != default ]] || section=default
    session="$(ini_get "$CONFIG_AWS" "$section" sso_session)"
    : >"$WORK_DIR/new-profile"
    for key in sso_start_url sso_region sso_account_id sso_role_name; do
        value="$(ini_get "$CONFIG_AWS" "$section" "$key")"
        if [[ -z "$value" ]]; then value="$(ini_get "$CONFIG_AWS" "$section" "granted_$key")"; fi
        if [[ -z "$value" && -n "$session" ]]; then value="$(ini_get "$CONFIG_AWS" "sso-session $session" "$key")"; fi
        if [[ -z "$value" ]]; then
            ask "$profile: enter $key supplied by your organisation:"
            value="$REPLY"
            [[ -n "$value" && "$value" != *$'\r'* ]] || error 'SSO settings must be non-empty single-line values.'
            if [[ "$key" == sso_start_url && "$value" != https://* ]]; then error 'The SSO start URL must use HTTPS.'; fi
            printf '%s = %s\n' "$key" "$value" >>"$WORK_DIR/new-profile"
        fi
    done
    if [[ -s "$WORK_DIR/new-profile" ]]; then
        original="$(resolve_file "$CONFIG_AWS")"
        if [[ -f "$original" ]]; then cat "$original"; fi >"$WORK_DIR/complete-profile"
        # A new section is safe only when no incomplete section already exists.
        if grep -Fqx "[$section]" "$WORK_DIR/complete-profile"; then
            error "Profile $profile already exists but is incomplete. Complete it with aws configure sso, then re-run."
        fi
        printf '\n[%s]\n' "$section" >>"$WORK_DIR/complete-profile"
        cat "$WORK_DIR/new-profile" >>"$WORK_DIR/complete-profile"
        write_file "$CONFIG_AWS" "$WORK_DIR/complete-profile"
    fi
}

# Set the top-level Granted browser, removing only its overriding SSO template.
configure_granted() {
    local file="$HOME/.granted/config" input
    input="$(resolve_file "$file")"; [[ -f "$input" ]] || input=/dev/null
    awk -v helper="$BREW_PREFIX/bin/aws-auto-approve" '
        BEGIN { print "CustomSSOBrowserPath = \"" helper "\"" }
        /^[[:space:]]*\[/ {
            header=$0; sub(/[[:space:]]*#.*/, "", header); gsub(/^[[:space:]]+|[[:space:]]+$/, "", header)
            skip=(header ~ /^\[SSOBrowserLaunchTemplate(\]|\.)/); section=1
        }
        skip { next }
        !section && /^[[:space:]]*CustomSSOBrowserPath[[:space:]]*=/ { next }
        { print }
    ' "$input" >"$WORK_DIR/granted-config"
    write_file "$file" "$WORK_DIR/granted-config"
}

# Install small shell blocks; runtime guards respect existing sourced frameworks.
configure_zsh() {
    local quoted_brew quoted_assume
    if [[ -z "$CONFIG_ZDOTDIR" ]]; then
        # Capture only the sentinel, never replay output from user startup files.
        (cd "$HOME" && /bin/zsh -lc 'printf "\nAWS_AUTO_ZDOTDIR=%s\n" "${ZDOTDIR:-$HOME}"') >"$WORK_DIR/zsh-probe" 2>&1 || error 'Zsh login startup failed; repair it before configuring.'
        CONFIG_ZDOTDIR="$(sed -n 's/^AWS_AUTO_ZDOTDIR=//p' "$WORK_DIR/zsh-probe" | tail -1)"
    fi
    [[ "$CONFIG_ZDOTDIR" == /* && "$CONFIG_ZDOTDIR" != *$'\n'* ]] || error 'ZDOTDIR must resolve to one absolute directory.'
    printf -v quoted_brew '%q' "$BREW"
    # shellcheck disable=SC2016 # Generate code for the next zsh login, not this Bash process.
    printf 'if ! command -v brew >/dev/null 2>&1; then\n  eval "$(%s shellenv)"\nfi\n' "$quoted_brew" >"$WORK_DIR/zprofile"
    # shellcheck disable=SC2016 # Keep the future zsh path array; remove duplicate entries there.
    printf 'typeset -U path\npath=(%q %q "$path[@]")\n' "$BREW_PREFIX/bin" "$BREW_PREFIX/sbin" >>"$WORK_DIR/zprofile"
    managed_block "$CONFIG_ZDOTDIR/.zprofile" homebrew "$WORK_DIR/zprofile"
    # shellcheck disable=SC2016 # Preserve the future zsh fpath expansion.
    printf 'typeset -U fpath\nfpath=(%q "$fpath[@]")\n' "$BREW_PREFIX/share/zsh/site-functions" >"$WORK_DIR/zpath"
    managed_block "$CONFIG_ZDOTDIR/.zshrc" completions "$WORK_DIR/zpath" start
    cat >"$WORK_DIR/ztools" <<'SHELL'
if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  compinit
fi
if [[ "${TERM:-}" != dumb ]] && (( ! $+functions[prompt_starship_precmd] )) && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
if (( ! $+functions[_direnv_hook] )) && command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
SHELL
    if [[ "$MODE" == with-granted ]]; then
        printf -v quoted_assume '%q' "${GRANTED%/*}/assume"
        printf 'alias assume=%q\nexport GRANTED_ALIAS_CONFIGURED=true\n' "source $quoted_assume" >>"$WORK_DIR/ztools"
        cat >>"$WORK_DIR/ztools" <<'SHELL'
# Complete configured AWS profile names without invoking a credential provider.
_aws_auto_assume_profiles() {
  local -a profiles
  profiles=("${(@f)$(aws configure list-profiles 2>/dev/null)}")
  _describe 'AWS profile' profiles
}
compdef _aws_auto_assume_profiles assume
SHELL
    fi
    managed_block "$CONFIG_ZDOTDIR/.zshrc" shell "$WORK_DIR/ztools"
    /bin/zsh -n "$CONFIG_ZDOTDIR/.zprofile" "$CONFIG_ZDOTDIR/.zshrc"
}

# Enable the AWS module while retaining the existing Starship format and theme.
configure_starship() {
    local file="${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}" input
    input="$(resolve_file "$file")"; [[ -f "$input" ]] || input=/dev/null
    awk '
        BEGIN { root=1 }
        /^\[/ { root=0; if (aws && !enabled) print "disabled = false"; aws=($0 ~ /^\[aws\][[:space:]]*$/); if (aws) seen=1; enabled=0 }
        root && /^[[:space:]]*format[[:space:]]*=/ {
            text=$0
            if (!match(text, /["\047]/)) exit 2
            start=RSTART; quote=substr(text,start,1); length_quote=1
            if (substr(text,start,3)==quote quote quote) { quote=quote quote quote; length_quote=3 }
            if (length_quote==3 && !index(substr(text,start+3),quote)) {
                closed=0
                while ((getline line)>0) { text=text "\n" line; if (index(line,quote)) { closed=1; break } }
                if (!closed) exit 2
            }
            if (text !~ /\$(aws|all)/) text=substr(text,1,start+length_quote-1) "$aws " substr(text,start+length_quote)
            print text
            next
        }
        aws && /^[[:space:]]*disabled[[:space:]]*=/ { print "disabled = false"; enabled=1; next }
        { print }
        END { if (aws && !enabled) print "disabled = false"; if (!seen) print "\n[aws]\ndisabled = false\nsymbol = \"AWS \"" }
    ' "$input" >"$WORK_DIR/starship" || error 'Unsupported Starship format; its file was left unchanged.'
    STARSHIP_CONFIG="$WORK_DIR/starship" starship print-config >"$WORK_DIR/starship-check" 2>"$WORK_DIR/starship-errors" || error 'Starship rejected the proposed configuration; its file was left unchanged.'
    [[ ! -s "$WORK_DIR/starship-errors" ]] || error 'Starship reported a configuration error; its file was left unchanged.'
    write_file "$file" "$WORK_DIR/starship"
}

# Keep Ghostty appearance intact and change only its shell launch command.
configure_ghostty() {
    local base="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty" file include
    local native="$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
    local shell="$BREW_PREFIX/bin/zsh"
    file="$base/config.ghostty"
    if [[ -f "$base/config" && ! -f "$file" ]]; then file="$base/config"; fi
    if [[ -s "$native" ]]; then file="$native"; fi
    [[ "$shell" != *[[:space:]]* ]] || error 'Homebrew prefixes containing whitespace are not supported by this Ghostty setup.'
    include="${XDG_CONFIG_HOME:-$HOME/.config}/aws-auto-approve/ghostty.conf"
    printf 'command = direct:%s --login\nenv = SHELL=%s\n' "$shell" "$shell" >"$WORK_DIR/ghostty"
    write_file "$include" "$WORK_DIR/ghostty"
    printf 'config-file = "%s"\n' "$include" >"$WORK_DIR/ghostty-include"
    # Ghostty loads includes after the parent, in order. Put our shell-only include last.
    managed_block "$file" shell "$WORK_DIR/ghostty-include"
}

# Write reviewed per-directory authentication without exporting temporary credentials.
configure_project() {
    local index="$1" directory file profile exclude
    local profiles=()
    directory="${PROJECTS[$index]}"; file="$directory/.envrc"
    read -r -a profiles <<<"${PROJECT_PROFILES[$index]}"
    : >"$WORK_DIR/envrc-block"
    for profile in "${profiles[@]}"; do
        if [[ "$MODE" == with-granted ]]; then
            printf 'GRANTED_ALIAS_CONFIGURED=true %q %q --exec true || return\n' "${GRANTED%/*}/assume" "$profile"
        else
            printf 'aws-auto-approve-login --if-needed %q || return\n' "$profile"
        fi
    done >>"$WORK_DIR/envrc-block"
    printf 'export AWS_PROFILE=%q\n' "${PROJECT_ACTIVE[$index]}" >>"$WORK_DIR/envrc-block"
    # Migrate only the exact wrapper lines from the documented earlier setup.
    if [[ -f "$file" ]]; then
        awk -v profiles=" ${PROJECT_PROFILES[$index]}" '
            /^aws-auto-approve-login --if-needed [A-Za-z0-9._@+-]+ \|\| return$/ && index(profiles," " $3 " ") { next }
            /^export AWS_PROFILE=[A-Za-z0-9._@+-]+$/ { split($2,pair,"="); if (index(profiles," " pair[2] " ")) next }
            { print }
        ' "$file" >"$WORK_DIR/project-base"
    else
        : >"$WORK_DIR/project-base"
    fi
    # Other unmanaged authentication may select a different provider or role.
    if grep -Eq '(assume|aws-auto-approve-login|AWS_PROFILE)' "$WORK_DIR/project-base" && ! grep -Fq '# >>> aws-auto-approve project >>>' "$WORK_DIR/project-base"; then
        error "Existing unmanaged AWS setup in $file. Move those authentication lines into the managed block or remove them after review, then re-run."
    fi
    if git -C "$directory" rev-parse --git-dir >/dev/null 2>&1; then
        if git -C "$directory" ls-files --error-unmatch .envrc >/dev/null 2>&1; then error "Tracked .envrc in $directory; use a local untracked file after team review."; fi
        if ! git -C "$directory" check-ignore -q .envrc; then
            exclude="$(git -C "$directory" rev-parse --path-format=absolute --git-path info/exclude)"
            printf '.envrc\n' >"$WORK_DIR/ignore"
            managed_block "$exclude" local-envrc "$WORK_DIR/ignore"
        fi
    fi
    info "Proposed authentication block for $file:"
    cat "$WORK_DIR/envrc-block"
    confirm 'Write this block and trust the complete .envrc? Review any existing content privately first.' || error 'Directory configuration cancelled.'
    managed_block "$file" project "$WORK_DIR/envrc-block" end "$WORK_DIR/project-base"
    if ((SKIP_LOGIN)); then
        warning "Not trusted yet: run direnv allow in $directory after reviewing it and testing sign-in."
    else
        (cd "$directory" && direnv allow .)
    fi
}

# Verify packaging and selected role access without revealing authentication data.
validate_installation() {
    local profile helper="$BREW_PREFIX/bin/aws-auto-approve" result=0
    [[ "$(command -v aws-auto-approve)" == "$helper" ]] || error 'An older helper shadows Homebrew. Move it aside and re-run.'
    "$helper" --help >/dev/null || error 'The native helper did not pass its help check.'
    "$BREW_PREFIX/bin/aws-auto-approve-login" --help >/dev/null || error 'The login wrapper did not pass its help check.'
    codesign --verify --deep --strict "$BREW_PREFIX/opt/aws-auto-approve/libexec/AWS Auto Approve.app" || error 'The installed app signature did not verify.'
    "$BREW" test stephenlclarke/tap/aws-auto-approve || { warning 'Homebrew formula test failed; continuing independent role checks.'; result=1; }
    if ((SKIP_LOGIN == 0)); then
        for profile in "${PROFILES[@]}"; do
            if [[ "$MODE" == with-granted ]]; then
                # Granted may print live request data; keep it private, never replay it.
                GRANTED_ALIAS_CONFIGURED=true "${GRANTED%/*}/assume" "$profile" --exec true >"$WORK_DIR/authentication" 2>&1 || error "Granted sign-in failed for $profile. Retry privately in your terminal."
            else
                "$BREW_PREFIX/bin/aws-auto-approve-login" "$profile" || error "AWS sign-in failed for $profile."
                "$BREW_PREFIX/bin/aws-auto-approve-login" --if-needed "$profile" || error "Cached access failed for $profile."
            fi
            AWS_PAGER='' aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1 || error "Role verification failed for $profile."
            info "Verified profile: $profile"
        done
    fi
    return "$result"
}

# Check startup in a fresh login shell, keeping unrelated startup output private.
validate_zsh() {
    (
        cd "$HOME"
        TERM=xterm-256color ZDOTDIR="$CONFIG_ZDOTDIR" AWS_AUTO_APPROVE_EXPECTED_PREFIX="$BREW_PREFIX" /bin/zsh -lic '
            (( $+commands[aws-auto-approve] && $+commands[aws-auto-approve-login] )) || exit 1
            [[ "$commands[aws-auto-approve]" == "$AWS_AUTO_APPROVE_EXPECTED_PREFIX/bin/aws-auto-approve" ]] || exit 1
            [[ "$commands[aws-auto-approve-login]" == "$AWS_AUTO_APPROVE_EXPECTED_PREFIX/bin/aws-auto-approve-login" ]] || exit 1
            (( $+functions[compdef] && $+functions[prompt_starship_precmd] && $+functions[_direnv_hook] )) || exit 1
            print -r -- AWS_AUTO_SETUP_OK
        '
    ) >"$WORK_DIR/zsh-validation" 2>&1 || return 1
    grep -Fxq AWS_AUTO_SETUP_OK "$WORK_DIR/zsh-validation"
}

# Report package versions without requesting credentials or dumping configuration.
report_versions() {
    info 'Installed Homebrew versions:'
    "$BREW" list --versions aws-auto-approve awscli zsh starship direnv
    if [[ "$MODE" == with-granted ]]; then "$GRANTED" -v; fi
}

# Run setup in dependency order and report checks that still need a fresh terminal.
main() {
    local profile index result=0
    init_colours
    parse_args "$@"
    [[ "$(uname -s)" == Darwin ]] || error 'This configure script requires macOS.'
    need awk
    need curl
    need git
    detect_tools
    choose_mode
    if ((DRY_RUN)); then show_plan; return; fi
    [[ "$EUID" != 0 ]] || error 'Run as your normal macOS user, not root.'
    umask 077
    WORK_DIR="$(mktemp -d)"
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    collect_projects
    show_plan
    confirm 'Install missing dependencies and configure this setup?' || error 'Setup cancelled.'
    install_dependencies
    for profile in "${PROFILES[@]}"; do ensure_profile_settings "$profile"; configure_profile "$profile"; done
    if [[ "$MODE" == with-granted ]]; then configure_granted; fi
    configure_zsh
    configure_starship
    configure_ghostty
    for ((index=0; index<${#PROJECTS[@]}; index++)); do configure_project "$index"; done
    validate_installation || result=$?
    if ! validate_zsh; then warning 'Fresh zsh startup checks failed. Review your startup files privately.'; result=1; fi
    report_versions
    info "Configured route: $MODE"
    if [[ -n "$BACKUP_DIR" ]]; then info "Backups and rollback mapping: $BACKUP_DIR/manifest.txt"; fi
    warning 'Open a fresh Ghostty window. Check command completion, the AWS profile prompt, and enter/leave each project to verify direnv restoration.'
    if ((SKIP_LOGIN)); then warning 'Configuration completed; live sign-in is unverified.'; fi
    return "$result"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
