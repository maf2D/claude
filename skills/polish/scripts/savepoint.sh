#!/bin/sh
# Snapshot or restore the whole working tree (tracked + untracked, minus ignored)
# without touching the real index, HEAD, or stash.
#   savepoint.sh save            -> prints a tree id
#   savepoint.sh restore <tree>  -> working tree matches <tree> again
set -eu
cd "$(git rev-parse --show-toplevel)"
tmp_index=$(mktemp -u "${TMPDIR:-/tmp}/polish-index.XXXXXX")
trap 'rm -f "$tmp_index"' EXIT

snapshot() {
  GIT_INDEX_FILE="$tmp_index" git add -A
  GIT_INDEX_FILE="$tmp_index" git write-tree
  rm -f "$tmp_index"
}

case "${1:-}" in
  save)
    snapshot
    ;;
  restore)
    target="${2:?usage: savepoint.sh restore <tree>}"
    now=$(snapshot)
    # files that exist now but not in the save point: delete them
    git diff -z --name-only --no-renames --diff-filter=A "$target" "$now" | xargs -0 rm -f --
    # folders left empty by that: remove them
    git diff -z --name-only --no-renames --diff-filter=A "$target" "$now" | xargs -0 -n1 dirname | sort -u | while IFS= read -r d; do
      [ "$d" = . ] || rmdir -p "$d" 2>/dev/null || true
    done
    # every file in the save point: write it back
    GIT_INDEX_FILE="$tmp_index" git read-tree "$target"
    GIT_INDEX_FILE="$tmp_index" git checkout-index -a -f
    ;;
  *)
    echo "usage: savepoint.sh save | restore <tree>" >&2
    exit 2
    ;;
esac
