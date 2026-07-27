#!/usr/bin/env bash
# Run `swift "$@"` on a toolchain new enough to resolve this package.
#
# desert-ant-core depends on JavaScriptKit, whose manifest declares swift-tools
# 6.2.0, so any Swift older than 6.2 fails to resolve the graph — including the
# 6.1.2 that Xcode 16.4 ships. mise's own swift provider has no macOS build, so
# find a 6.2 toolchain here: a current Xcode if it has one, otherwise swiftly.
#
# XCTest ships with Xcode rather than CommandLineTools or the OSS toolchains, so
# DEVELOPER_DIR must point at Xcode either way.
#
#   scripts/with-swift.sh test
#   scripts/with-swift.sh run TongueCLIExample
set -euo pipefail

if [ -d /Applications/Xcode.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

version=$(swift --version 2>/dev/null | sed -n 's/.*Apple Swift version \([0-9]*\.[0-9]*\).*/\1/p')

if [ -n "$version" ] && [ "$(printf '%s\n6.2' "$version" | sort -V | head -1)" = "6.2" ]; then
    exec swift "$@"
fi

if command -v swiftly >/dev/null 2>&1; then
    echo "Xcode ships Swift ${version:-unknown}; using swiftly's 6.2.0 for resolution" >&2
    # shellcheck disable=SC1091
    . "$HOME/.swiftly/env.sh"
    swiftly install 6.2.0 --assume-yes >/dev/null 2>&1 || true
    exec swiftly run swift "$@" +6.2.0
fi

echo "error: Swift 6.2+ required (desert-ant-core needs it). Update Xcode, or install swiftly." >&2
exit 1
