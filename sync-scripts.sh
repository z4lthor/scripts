#!/bin/bash
# Creates links for scripts found recursively in a source directory
# Author: z4lthor <z4lthor@gmail.com>

set -euo pipefail

SRC_DIR=${1:-}
DEST_DIR="$HOME/.local/bin"

check_shebang() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1
    [[ "$(head -n 1 "$file" 2>/dev/null)" =~ ^#! ]]
}

if [[ -z "$SRC_DIR" ]]; then
    echo "Usage: $(basename "$0") SOURCE"
    exit 1
fi

SRC_DIR=$(realpath -m "$SRC_DIR")

if [[ ! -d "$SRC_DIR" ]]; then
    echo "Error: Source directory $SRC_DIR doesn't exist" >&2
    exit 1
fi

echo "Source: $SRC_DIR"
echo "Destination: $DEST_DIR"

mkdir -p "$DEST_DIR"

echo "Clean up broken symbolic links from $DEST_DIR ..."

find "$DEST_DIR" -type l -xtype l -delete

total=0
created=0
skipped=0
conflicts=0

echo "Syncing scripts from $SRC_DIR ..."

while IFS= read -r -d '' script; do
    ((total++)) || :

    name=$(basename "$script")
    link="$DEST_DIR/${name%.sh}"

    if [[ ! -x "$script" ]]; then
        echo "Skipping: $name is not executable" >&2
        ((skipped++)) || :
        continue
    fi

    if ! check_shebang "$script"; then
        echo "Skipping: $name missing or not using interpreter" >&2
        ((skipped++)) || :
        continue
    fi

    if [[ -L "$link" ]] || [[ -e "$link" ]]; then
        target_path=$(readlink -f "$link" 2>/dev/null)
        exit_code=$?

        if [[ $exit_code -ne 0 ]] || [[ -z "$target_path" ]]; then
            echo "Warning: $link is a broken symlink or trapped in a loop" >&2
            ((conflicts++)) || :
            continue
        fi

        if [[ "$target_path" == "$script" ]]; then
            echo "Skipping: $link already exists and points to $script" >&2
            ((skipped++)) || :
            continue
        else
            echo "Conflict: $link already exists and points elsewhere ($target_path)" >&2
            ((conflicts++)) || :
            continue
        fi
    fi

    if ln -s "$script" "$link" 2>/dev/null; then
        echo "Created: $link -> $script"
        ((created++)) || :
    else
        echo "Error: Failed to create link $name" >&2
        ((conflicts++)) || :
    fi

done < <(find "$SRC_DIR" -type f -not -path "*/.*" \( -executable -o -name "*.sh" \) -print0)

echo "Summary: Total $total | Created $created | Skipped $skipped | Conflicts $conflicts"
