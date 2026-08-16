#!/usr/bin/env bash

set -euo pipefail

version=$(awk -F': *' '$1 == "Version" { print $2; exit }' control)
if [[ -z "${version}" ]]; then
    echo "Unable to read Version from control." >&2
    exit 1
fi

dylib_found=$(find packages -maxdepth 1 -type f -name '*.dylib' 2>/dev/null | wc -l | tr -d ' ')
if [[ "${dylib_found}" -lt 1 ]]; then
    echo "Missing dylib asset in packages directory." >&2
    find .theos packages -type f 2>/dev/null | sort >&2
    exit 1
fi

deb_found=$(find packages -maxdepth 1 -type f -name '*.deb' 2>/dev/null | wc -l | tr -d ' ')
if [[ "${deb_found}" -lt 1 ]]; then
    echo "Missing deb package in packages directory." >&2
    find .theos packages -type f 2>/dev/null | sort >&2
    exit 1
fi

echo "Successfully verified FLEX++ release assets:"
find packages -maxdepth 1 -type f -print | sort

