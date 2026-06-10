#!/usr/bin/env bash
# PreToolUse: block edits to generated artifacts that get rewritten by tooling.
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[[ -z "$file_path" ]] && exit 0

case "$file_path" in
    */.build/*)
        echo "Blocked: '$file_path' is a SwiftPM build output (.build/). Edit the sources under Sources/ and rebuild." >&2
        exit 2
        ;;
    */DerivedData/*|*/.derived-data/*)
        echo "Blocked: '$file_path' is Xcode-derived data. Edit the sources and rebuild." >&2
        exit 2
        ;;
    *.xcodeproj/*|*.xcworkspace/*)
        echo "Blocked: '$file_path' is a generated Xcode project. This is an SPM package — edit Package.swift and the Swift sources instead." >&2
        exit 2
        ;;
    */.swiftpm/xcode/*|*/.swiftpm/configuration/*)
        echo "Blocked: '$file_path' is generated SwiftPM/Xcode state under .swiftpm/. Edit Package.swift instead." >&2
        exit 2
        ;;
esac

exit 0
