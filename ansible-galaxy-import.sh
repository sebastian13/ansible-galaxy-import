#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
DRY_RUN=0
ONLY_REPO=""

usage() {
	cat <<'EOF'
Bulk import/update ansible-* repositories in Ansible Galaxy.

Usage:
	./ansible-galaxy-import.sh [options]

Options:
	--base-dir PATH      Directory that contains ansible-* repositories.
										 Default: parent directory of script
	--env-file PATH      Path to env file with ANSIBLE_GALAXY_TOKEN.
										 Default: <script-dir>/.env
	--only REPO          Import only one repository name (e.g. ansible-restic).
	--dry-run            Print what would be executed without running imports.
	-h, --help           Show this help.

Environment:
	ANSIBLE_GALAXY_TOKEN Must be set or present in env file.

Notes:
	- This script detects owner/repo from each repository's origin URL.
	- Only directories that look like Ansible roles are imported.
	- Role check requires meta/main.yml and one standard role directory.
	- Running import on an existing Galaxy role triggers metadata refresh.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--base-dir)
			BASE_DIR="$2"
			shift 2
			;;
		--env-file)
			ENV_FILE="$2"
			shift 2
			;;
		--only)
			ONLY_REPO="$2"
			shift 2
			;;
		--dry-run)
			DRY_RUN=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage
			exit 1
			;;
	esac
done

if [[ -f "$ENV_FILE" ]]; then
	set -a
	# shellcheck disable=SC1090
	source "$ENV_FILE"
	set +a
fi

if [[ $DRY_RUN -eq 0 && ( -z "${ANSIBLE_GALAXY_TOKEN:-}" || "${ANSIBLE_GALAXY_TOKEN}" == "your_token_here" ) ]]; then
	echo "ERROR: ANSIBLE_GALAXY_TOKEN is missing or placeholder value." >&2
	echo "Set it in environment or in $ENV_FILE." >&2
	exit 1
fi

if ! command -v ansible-galaxy >/dev/null 2>&1; then
	echo "ERROR: ansible-galaxy command not found." >&2
	exit 1
fi

parse_origin() {
	local origin="$1"
	local path=""

	if [[ "$origin" =~ ^git@github\.com:(.+)$ ]]; then
		path="${BASH_REMATCH[1]}"
	elif [[ "$origin" =~ ^https://github\.com/(.+)$ ]]; then
		path="${BASH_REMATCH[1]}"
	else
		return 1
	fi

	path="${path%.git}"
	if [[ ! "$path" =~ ^[^/]+/[^/]+$ ]]; then
		return 1
	fi

	echo "$path"
}

is_ansible_role_repo() {
	local repo_path="$1"

	if [[ ! -f "$repo_path/meta/main.yml" ]]; then
		return 1
	fi

	if [[ -d "$repo_path/tasks" || -d "$repo_path/handlers" || -d "$repo_path/defaults" || -d "$repo_path/vars" ]]; then
		return 0
	fi

	return 1
}

success_count=0
fail_count=0
skip_count=0

echo "Base directory: $BASE_DIR"
echo "Env file: $ENV_FILE"
if [[ $DRY_RUN -eq 1 ]]; then
	echo "Mode: dry-run"
fi

shopt -s nullglob
for repo_path in "$BASE_DIR"/ansible-*; do
	repo_name="$(basename "$repo_path")"

	if [[ ! -d "$repo_path" ]]; then
		continue
	fi

	if [[ -n "$ONLY_REPO" && "$repo_name" != "$ONLY_REPO" ]]; then
		continue
	fi

	if [[ ! -d "$repo_path/.git" ]]; then
		echo "SKIP $repo_name: not a git repository"
		((skip_count++))
		continue
	fi

	if ! is_ansible_role_repo "$repo_path"; then
		echo "SKIP $repo_name: not an Ansible role repository (meta/main.yml missing or incomplete role structure)"
		((skip_count++))
		continue
	fi

	origin_url="$(git -C "$repo_path" remote get-url origin 2>/dev/null || true)"
	if [[ -z "$origin_url" ]]; then
		echo "SKIP $repo_name: missing origin remote"
		((skip_count++))
		continue
	fi

	owner_repo="$(parse_origin "$origin_url" || true)"
	if [[ -z "$owner_repo" ]]; then
		echo "SKIP $repo_name: unsupported origin URL '$origin_url'"
		((skip_count++))
		continue
	fi

	owner="${owner_repo%%/*}"
	repo="${owner_repo##*/}"

	echo "IMPORT $owner/$repo"
	if [[ $DRY_RUN -eq 1 ]]; then
		continue
	fi

	if ansible-galaxy role import "$owner" "$repo" --token "$ANSIBLE_GALAXY_TOKEN"; then
		((success_count++))
	else
		((fail_count++))
		echo "FAILED $owner/$repo"
	fi
done
shopt -u nullglob

echo
echo "Summary:"
echo "  Success: $success_count"
echo "  Failed:  $fail_count"
echo "  Skipped: $skip_count"

if [[ $DRY_RUN -eq 0 && $fail_count -gt 0 ]]; then
	exit 1
fi

exit 0
