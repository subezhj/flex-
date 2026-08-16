#!/usr/bin/env bash

set -euo pipefail

notes_file=${1:-release-notes.md}
version=$(awk -F': *' '$1 == "Version" { print $2; exit }' control)
release_sha=${RELEASE_SHA:-${GITHUB_SHA:-HEAD}}

if [[ -z "${version}" ]]; then
    echo "Unable to read Version from control." >&2
    exit 1
fi

cat > "${notes_file}" <<NOTES
## FLEX++ ${version}

- Commit: \`${release_sha}\`
- Deb Package: \`FLEX++_${version}.deb\`
- Dynamic Library: \`FLEX++_${version}.dylib\`
NOTES
