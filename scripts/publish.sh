#!/usr/bin/env bash
# Usage: publish.sh <version>. Run through `just publish`, which sets MANIFEST.
set -euo pipefail

version=$1
tag="v$version"
[[ "$(git branch --show-current)" == main ]] || {
  echo "publish from main" >&2
  exit 1
}
[[ -z "$(git status --porcelain)" ]] || {
  echo "commit or stash the changes first" >&2
  exit 1
}
git fetch --quiet --tags origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || {
  echo "main differs from origin/main: push or pull first" >&2
  exit 1
}
if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
  echo "$tag already exists" >&2
  exit 1
fi
ci=$(gh run list --commit "$(git rev-parse HEAD)" --workflow CI --json status,conclusion --jq '.[0] | "\(.status) \(.conclusion)"')
[[ "$ci" == "completed success" ]] || {
  echo "CI has not passed on HEAD (${ci:-no run}): wait for it or fix it" >&2
  exit 1
}
just set-version "$version"
git diff --quiet || git commit --quiet -m "Publish $version" "$MANIFEST" src-tauri/Cargo.lock
tree=$(mktemp -d)
trap 'git worktree remove --force "$tree"' EXIT
git worktree add --quiet --detach "$tree" HEAD
(cd "$tree" && mise trust --quiet && just deps frozen && just build)
archive=$(cd "$tree" && just package "$version")
git tag -a "$tag" -m "focustube $version"
git push --quiet origin main "$tag"
gh release create "$tag" --title "focustube $version" --generate-notes "$tree/$archive"
