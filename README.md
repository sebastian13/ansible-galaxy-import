# ansible-galaxy-import

Bulk import/update helper for Ansible Galaxy roles hosted in GitHub repositories.

## What Changed for Subdirectory Usage

This repository can live in a dedicated subdirectory (for example `github.com/ansible-galaxy-import`).

The script uses these defaults:

- `BASE_DIR`: parent directory of the script (for example `github.com/`)
- `ENV_FILE`: `.env` inside this repository

All ansible-galaxy role repos should be siblings of this repository. This ensures the default call works out of the box.

## How Role Detection Works

The script scans only repositories matching `ansible-*`, then imports repositories when the 
following conditions are met:

- `meta/main.yml` exists
- at least one role directory exists: `tasks/`, `handlers/`, `defaults/`, or `vars/`

This automatically skips this tool repository (`ansible-galaxy-import`) as it is not a role.

## Requirements

- `ansible-galaxy` CLI available in PATH
- GitHub repositories with `origin` remote
- `ANSIBLE_GALAXY_TOKEN` in environment or `.env`

## Setup

1. Copy `.env.example` to `.env` (or create `.env`).
2. Set your token:

```bash
ANSIBLE_GALAXY_TOKEN=your_real_token
```

## Usage

Dry run:

```bash
./ansible-galaxy-import.sh --dry-run
```

Import/update all matching roles:

```bash
./ansible-galaxy-import.sh
```

Import/update one specific repository:

```bash
./ansible-galaxy-import.sh --only ansible-restic
```

Use a custom scan directory:

```bash
./ansible-galaxy-import.sh --base-dir /path/to/repos
```

## Options

- `--base-dir PATH`: Directory containing `ansible-*` repositories
- `--env-file PATH`: Path to environment file with token
- `--only REPO`: Process only one repo name
- `--dry-run`: Print actions without importing
- `-h`, `--help`: Show help

## Example Output

- `IMPORT sebastian13/ansible-restic`
- `SKIP ansible-galaxy-import: not an Ansible role repository (...)`

## Security Note

Do not commit your real `.env` file. `.gitignore` is configured to exclude it.
