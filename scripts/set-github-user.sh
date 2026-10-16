#!/usr/bin/env bash
# Usage: ./scripts/set-github-user.sh <github-username> [repo-name]
set -euo pipefail
cd "$(dirname "$0")/.."
USER_NAME="${1:?usage: $0 <github-username> [repo-name]}"
REPO_NAME="${2:-final-devops-project}"
LOWER="$(echo "$USER_NAME" | tr '[:upper:]' '[:lower:]')"   # container registries require lowercase

FILES=$(grep -rlE "YOUR_GITHUB_USERNAME|final-devops-project\.git" --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.terraform . | grep -v -e scripts/set-github-user.sh -e README_PERSONAL.md || true)
for f in $FILES; do
  sed -i.bak \
    -e "s#ghcr.io/YOUR_GITHUB_USERNAME#ghcr.io/$LOWER#g" \
    -e "s#github.com/YOUR_GITHUB_USERNAME/final-devops-project.git#github.com/$USER_NAME/$REPO_NAME.git#g" \
    -e "s#YOUR_GITHUB_USERNAME/final-devops-project#$USER_NAME/$REPO_NAME#g" \
    -e "s#YOUR_GITHUB_USERNAME#$USER_NAME#g" "$f"
  rm -f "$f.bak"
  echo "updated $f"
done
echo "Done. Review with: git diff"
