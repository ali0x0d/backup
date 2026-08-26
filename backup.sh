#!/bin/bash

set -e

readonly SCRIPT_NAME=$(basename "$0")
readonly TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

config_file=""
target_os=""
is_dry_run=false
is_archive_enabled=true

usage() {
    cat <<EOF
Usage:
    $SCRIPT_NAME [linux|android] [OPTIONS]

Options:
    --dry-run
    --no-archive
    -h, --help
EOF
}

error() {
    echo "$1"
    echo
    usage
    exit 1
}

parse_args() {
    if [[ $# -gt 0 ]]; then
        case "$1" in
            linux|android)
                target_os="$1"
                shift
                ;;
            -*)
                ;;
            *)
                error "Invalid target OS: '$1'"
                ;;
        esac
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                is_dry_run=true
                ;;
            --no-archive)
                is_archive_enabled=false
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            linux|android)
                error "Target OS must be the first argument."
                ;;
            *)
                error "Unknown option: '$1'"
                ;;
        esac
        shift
    done
}

load_config() {
    local user_home

    if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        user_home=$HOME
    fi

    local config_dir="${user_home}/.config/backup"

    if [[ ! -d "$config_dir" ]]; then
        mkdir -p "$config_dir"

        if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
            chown "$SUDO_USER:$SUDO_USER" "$config_dir"
        fi
    fi

    config_file="${config_dir}/config"

    if [[ -f "$config_file" ]]; then
        source "$config_file"
    fi
}

save_config() {
    local tmp=$(mktemp)
    chmod 600 "$tmp"
    cat > "$tmp" <<EOF
backup_root_path="${backup_root_path:-}"
android_src="${android_src:-}"
EOF
    if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
        chown "$SUDO_USER:$SUDO_USER" "$tmp"
    fi
    mv "$tmp" "$config_file"
}

prompt_path() {
    declare -n path="$1"
    local path_name="$2"
    local path_eg="$3"

    if [[ -d "$path" ]]; then
        while true; do
            read -rp "Use $path_name '$path'? [Y/n]: " answer

            case "${answer,,}" in
                ""|y|yes)
                    return
                    ;;
                n|no)
                    break
                    ;;
                *)
                    echo "Please enter 'y' or 'n'."
                    ;;
            esac
        done
    fi

    while true; do
        read -rp "Enter $path_name (e.g. $path_eg): " path

        path="${path%/}"

        if [[ -d "$path" ]]; then
            break
        else
            echo "'$path' does not exist."
        fi
    done
}

run_rsync() {
    local src="$1"
    local dest="$2"
    shift 2

    local rsync_opts=(-av --delete --delete-excluded)
    $is_dry_run && rsync_opts+=(--dry-run)
    rsync_opts+=("$@")

    rsync "${rsync_opts[@]}" "$src" "$dest"
}

backup() {
    local backup_src backup_dest backup_archive
    local rsync_opts=()

    prompt_path backup_src "backup source path" "/var/www/html"
    prompt_path backup_dest "backup destination path" "/mnt/backup"

    backup_archive="${backup_dest}/archive"

    $is_archive_enabled && rsync_opts+=(--backup --backup-dir="${backup_archive}/${TIMESTAMP}")

    run_rsync "$backup_src" "$backup_dest" "${rsync_opts[@]}"
}

backup_linux() {
    prompt_path backup_root_path "backup root path" "/mnt/backup"

    local linux_src="/home"
    local linux_dest="${backup_root_path}/linux"
    local linux_archive="${linux_dest}/archive"
    local rsync_opts=()

    mkdir -p "$linux_dest"

    $is_archive_enabled && rsync_opts+=(--backup --backup-dir="${linux_archive}/${TIMESTAMP}")

    run_rsync "$linux_src" "$linux_dest" "${rsync_opts[@]}"
}

backup_android() {
    prompt_path android_src "android source path" "/run/internal"
    prompt_path backup_root_path "backup root path" "/mnt/backup"

    local android_src_basename=$(basename "$android_src")
    local android_dest="${backup_root_path}/android"
    local android_archive="${android_dest}/archive"
    local rsync_opts=()

    mkdir -p "$android_dest"

    $is_archive_enabled && rsync_opts+=(--backup --backup-dir="${android_archive}/${TIMESTAMP}")

    rsync_opts+=(
        --exclude="/${android_src_basename}/Android/data"
        --exclude="/${android_src_basename}/Android/obb"
        --exclude="/${android_src_basename}/Android/.Trash"
        --exclude="**/.thumbnails/"
    )

    run_rsync "$android_src" "$android_dest" "${rsync_opts[@]}"
}

main() {
    parse_args "$@"

    if [[ "$target_os" == "linux" && $EUID -ne 0 ]]; then
        exec sudo "$0" "$@"
    fi

    load_config

    case "$target_os" in
        "")      backup ;;
        linux)   backup_linux ;;
        android) backup_android ;;
    esac

    save_config

    if $is_dry_run; then
        echo "✓ Dry run completed successfully. No changes were made."
    else
        echo "✓ Backup completed successfully."
    fi
}

main "$@"
