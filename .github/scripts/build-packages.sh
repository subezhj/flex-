#!/usr/bin/env bash

set -euo pipefail

rm -rf packages
mkdir -p packages

make package FINALPACKAGE=1 THEOS_PACKAGE_DIR=packages

version=$(awk -F': *' '$1 == "Version" { print $2; exit }' control)
if [[ -f "packages/FLEX++.dylib" ]]; then
    cp "packages/FLEX++.dylib" "packages/FLEX++_${version}.dylib"
fi

