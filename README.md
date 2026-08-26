# backup

A small Bash wrapper around `rsync` that mirrors directories to a backup drive and keeps a
timestamped archive of everything it overwrites or deletes.

## Features

- Three modes: an interactive ad-hoc backup, a `linux` preset for `/home`, and an `android` preset
  for a mounted phone.
- Every changed or deleted file is moved into `<destination>/archive/<timestamp>/` instead of being
  lost, so a mirror never destroys an older version.
- Remembers the paths you answered last time in `~/.config/backup/config`.
- `--dry-run` shows exactly what would happen without touching anything.

## Requirements

- Bash 4.3 or newer (the script uses `declare -n` namerefs)
- `rsync`
- `sudo` for `linux` mode — the script re-executes itself with `sudo` automatically

## Installation

Clone the repo, so you can pull updates later:

```sh
git clone https://github.com/ali0x0d/backup.git
cd backup
chmod +x backup.sh
```

Or grab just the script:

```sh
curl -fsSLO https://raw.githubusercontent.com/ali0x0d/backup/main/backup.sh
chmod +x backup.sh
```

It runs `rsync --delete` and asks for `sudo` in `linux` mode, so read it before you run it.

Optionally put it on your `PATH`:

```sh
sudo install -m 755 backup.sh /usr/local/bin/backup
```

## Usage

```
backup.sh [linux|android] [OPTIONS]

Options:
    --dry-run       Show what would be transferred, change nothing
    --no-archive    Overwrite/delete in place instead of archiving
    -h, --help      Show help
```

The target OS, if given, must be the **first** argument.

### Modes

| Command | Source | Files land in |
| --- | --- | --- |
| `./backup.sh` | prompted | `<destination>/<source dir name>/` |
| `./backup.sh linux` | `/home` | `<backup root>/linux/home/` |
| `./backup.sh android` | prompted (e.g. `/run/internal`) | `<backup root>/android/internal/` |

The source path is passed to rsync without a trailing slash, so the source directory itself is
recreated inside the destination rather than having its contents dumped there directly.

Each prompt offers the previously saved path as the default, so repeat runs are just a few
<kbd>Enter</kbd> presses.

`android` mode excludes the directories that are large and not worth backing up:
`Android/data`, `Android/obb`, `Android/.Trash`, and any `.thumbnails/`.

### Examples

```sh
# Preview a full home-directory backup
./backup.sh linux --dry-run

# Back up /home to the saved backup root
./backup.sh linux

# Mirror a phone mounted at /run/internal, no archive copies
./backup.sh android --no-archive

# Ad-hoc: prompts for both source and destination
./backup.sh
```

## How it works

The script runs `rsync -av --delete --delete-excluded`, so **the destination becomes an exact mirror
of the source**: files removed from the source are removed from the destination too.

Unless you pass `--no-archive`, it also adds `--backup --backup-dir=<destination>/archive/<timestamp>`.
Anything rsync would overwrite or delete is moved into that timestamped directory first, so a mirror
run is recoverable:

```
/mnt/backup/linux/
├── home/                      # current mirror of /home
│   └── <username>/
└── archive/
    ├── 2026-08-20_09-14-02/   # files as they were before that run
    └── 2026-08-26_13-21-47/
```

Archive directories are never pruned automatically — delete old ones yourself when the drive fills up.

> **Warning:** `--delete` is destructive. Run with `--dry-run` first any time you point the script at
> a new destination, and make sure the destination path is a backup target and not a directory you
> care about.

## Configuration

Saved after every successful run to `~/.config/backup/config` (under the invoking user's home, even
when run through `sudo`):

```sh
backup_root_path="/mnt/backup"
android_src="/run/internal"
```

It is sourced as shell code on startup. Delete the file to be prompted from scratch.

## License

[MIT](LICENSE)
