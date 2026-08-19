#!/usr/bin/env bash

set -euo pipefail

rm -rf packages
mkdir -p packages

make all package FINALPACKAGE=1 || make package FINALPACKAGE=1 || true

version=$(awk -F': *' '$1 == "Version" { print $2; exit }' control)

# Stage exactly 1 versioned dylib
dylib_file=$(find .theos -name '*FLEX*.dylib' 2>/dev/null | head -1)
if [[ -n "${dylib_file}" && -f "${dylib_file}" ]]; then
    cp -f "${dylib_file}" "packages/FLEX++_${version}.dylib"
fi

# Stage exactly 1 versioned deb file
deb_file=$(find .theos packages -name '*.deb' 2>/dev/null | head -1)
if [[ -n "${deb_file}" && -f "${deb_file}" ]]; then
    cp -f "${deb_file}" "packages/FLEX++_${version}.deb"
fi

# Remove any extra unversioned or duplicate files
find packages -maxdepth 1 -type f -name '*.deb' ! -name "FLEX++_${version}.deb" -exec rm -f {} +
find packages -maxdepth 1 -type f -name '*.dylib' ! -name "FLEX++_${version}.dylib" -exec rm -f {} +

