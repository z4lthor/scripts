#!/bin/bash
# Creates links for scripts found recursively in a source directory
# Author: z4lthor <z4lthor@gmail.com>

set -euo pipefail

SRC_DIR=${1:-}
DEST_DIR="$HOME/.local/bin"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

check_shebang() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1
    [[ "$(head -n 1 "$file" 2>/dev/null)" =~ ^#! ]]
}

check_shadowing() {
    local link="$1"
    local name
    local found

    name=$(basename "$link")
    found=$(command -v "$name" 2>/dev/null)

    if [[ -n "$found" && "$found" != "$link" ]]; then
        return 0
    fi

    return 1
}

cleanup_broken_links() {
    local dir="$1"

    find "$dir" -type l -xtype l -delete
}

find_scripts() {
    local dir="$1"

    find "$dir" -type f -not -path "*/.*" \( -executable -o \( -name "*.sh" -a -readable \) \) -print0
}

log() {
    local type="$1"
    local msg="$2"
    local color
    local fd=1

    case "$type" in
        "INFO")
            color="$GREEN"
            ;;
        "WARNING")  
            color="$YELLOW"
            ;;
        "ERROR")
            color="$RED"
            fd=2
            ;;
        *)
            color=""
            ;;
    esac

    printf "${color}[%s]${RESET} %s\n" "$type" "$msg" >&$fd
}

info() {
    local msg="$1"

    log "INFO" "$msg"
}

warning() {
    local msg="$1"

    log "WARNING" "$msg"
}

error() {
    local msg="$1"

    log "ERROR" "$msg"
}

if [[ -z "$SRC_DIR" ]]; then
    echo "Usage: ${0##*/} SOURCE"
    exit 1
fi

SRC_DIR=$(realpath -m "$SRC_DIR")

if [[ ! -d "$SRC_DIR" ]]; then
    error "Source directory $SRC_DIR doesn't exist"
    exit 1
fi

info "Source: $SRC_DIR"
info "Destination: $DEST_DIR"

mkdir -p "$DEST_DIR"

info "Clean up broken symbolic links from $DEST_DIR ..."

cleanup_broken_links "$DEST_DIR"

total=0
created=0
skipped=0
conflicts=0

info "Syncing scripts from $SRC_DIR"

while IFS= read -r -d '' script; do
    ((total++)) || :

    name=$(basename "$script")
    link="$DEST_DIR/${name%.sh}"

    if [[ ! -x "$script" ]]; then
        warning "Skipping: $name is not executable"
        ((skipped++)) || :
        continue
    fi

    if ! check_shebang "$script"; then
        warning "Skipping: $name missing or not using interpreter"
        ((skipped++)) || :
        continue
    fi

    if check_shadowing "$link"; then
        warning "Conflict: $name shadows existing command"
        ((conflicts++)) || :
        continue
    fi

    if [[ -e "$link" || -L "$link" ]]; then
        target_path=$(readlink -f "$link" 2>/dev/null)
        exit_code=$?

        if [[ $exit_code -ne 0 ]] || [[ -z "$target_path" ]]; then
            warning "Conflict: $link is a broken symlink or trapped in a loop"
            ((conflicts++)) || :
            continue
        fi

        if [[ "$target_path" == "$script" ]]; then
            warning "Skipping: $link already exists and points to $script"
            ((skipped++)) || :
            continue
        else
            warning "Conflict: $link already exists and points elsewhere ($target_path)"
            ((conflicts++)) || :
            continue
        fi
    fi

    if ln -s "$script" "$link" 2>/dev/null; then
        info "Creating: $link -> $script"
        ((created++)) || :
    else
        error "Conflict: Failed to create link $name"
        ((conflicts++)) || :
    fi

done < <(find_scripts "$SRC_DIR")

info "Total $total | Created $created | Skipped $skipped | Conflicts $conflicts"
