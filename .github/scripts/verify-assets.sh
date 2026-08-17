#!/usr/bin/env bash

set -euo pipefail

version=$(awk -F': *' '$1 == "Version" { print $2; exit }' control)
if [[ -z "${version}" ]]; then
    echo "Unable to read Version from control." >&2
    exit 1
fi

dylib_count=$(find packages -maxdepth 1 -type f -name '*.dylib' 2>/dev/null | wc -l | tr -d ' ')
if [[ "${dylib_count}" != "1" ]]; then
    echo "Expected exactly 1 dylib asset, found ${dylib_count}." >&2
    find .theos packages -type f 2>/dev/null | sort >&2
    exit 1
fi

deb_count=$(find packages -maxdepth 1 -type f -name '*.deb' 2>/dev/null | wc -l | tr -d ' ')
if [[ "${deb_count}" != "1" ]]; then
    echo "Expected exactly 1 deb package, found ${deb_count}." >&2
    find .theos packages -type f 2>/dev/null | sort >&2
    exit 1
fi

echo "Successfully verified FLEX++ release assets (1 versioned dylib & 1 deb):"
find packages -maxdepth 1 -type f -print | sort

