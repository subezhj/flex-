#!/usr/bin/env bash

set -euo pipefail

rm -rf packages
mkdir -p packages

make all package FINALPACKAGE=1 || make package FINALPACKAGE=1 || true

version=$(awk -F': *' '$1 == "Version" { print $2; exit }' control)

# Clean up any unversioned dylib
rm -f packages/FLEX++.dylib

if [[ ! -f "packages/FLEX++_${version}.dylib" ]]; then
    dylib_file=$(find .theos -name '*.dylib' 2>/dev/null | head -1)
    if [[ -n "${dylib_file}" && -f "${dylib_file}" ]]; then
        cp -f "${dylib_file}" "packages/FLEX++_${version}.dylib"
    fi
fi

if [[ ! -f "packages/FLEX++_${version}.deb" ]]; then
    deb_file=$(find .theos -name '*.deb' 2>/dev/null | head -1)
    if [[ -n "${deb_file}" && -f "${deb_file}" ]]; then
        cp -f "${deb_file}" "packages/FLEX++_${version}.deb"
    fi
fi

