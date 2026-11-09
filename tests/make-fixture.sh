#!/usr/bin/env bash
# Builds the quiz-me fixture repo from tests/branches/.
#
# Usage: make-fixture.sh <dest>
#   <dest> must be missing or empty. It becomes a git repo with:
#   - main: the files in branches/base/
#   - one branch per other folder in branches/, made by copying that folder's
#     files over main and committing. Inside each folder:
#       .message  the commit message (optional)
#       .delete   paths to remove on that branch, one per line (optional)
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/branches"
dest="${1:?usage: make-fixture.sh <dest>}"

mkdir -p "$dest"
if [ -n "$(ls -A "$dest")" ]; then
  echo "make-fixture: $dest is not empty" >&2
  exit 1
fi
cd "$dest"

git init -q -b main
git config user.name "Fixture Developer"
git config user.email "fixture@example.com"
git config core.autocrlf false

cp -R "$SRC/base/." .
git add -A
git commit -q -m "Initial users-app"

for dir in "$SRC"/*/; do
  name="$(basename "$dir")"
  [ "$name" = base ] && continue

  git checkout -q -b "$name" main
  cp -R "$dir." .
  rm -f .message .delete

  if [ -f "$dir.delete" ]; then
    while IFS= read -r path || [ -n "$path" ]; do
      path="${path%$'\r'}"
      [ -n "$path" ] && git rm -q -- "$path"
    done < "$dir.delete"
  fi

  message="$name"
  [ -f "$dir.message" ] && message="$(tr -d '\r' < "$dir.message")"
  git add -A
  git commit -q -m "$message"
done

git checkout -q main
echo "$dest"
