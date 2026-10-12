#!/usr/bin/env bash
# Builds the iphonesim command into one self-contained binary and installs it.
#
#   tool/install.sh                      -> ~/.local/bin/iphonesim
#   PREFIX=/usr/local tool/install.sh    -> /usr/local/bin/iphonesim
#   DART=/path/to/dart tool/install.sh   (if dart/flutter aren't on PATH)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

dart="${DART:-}"
if [[ -z "$dart" ]]; then
  if command -v dart >/dev/null; then
    dart=dart
  elif command -v flutter >/dev/null; then
    dart="$(dirname "$(readlink -f "$(command -v flutter)")")/dart"
  elif [[ -x "$HOME/development/flutter/bin/dart" ]]; then
    dart="$HOME/development/flutter/bin/dart"
  else
    echo "Need dart or flutter on PATH (or DART=/path/to/dart)." >&2
    exit 1
  fi
fi

bin="${PREFIX:-$HOME/.local}/bin"
cd "$root/packages/iphonesim"
"$dart" pub get >/dev/null
"$dart" run tool/bundle_shell.dart >/dev/null
mkdir -p "$bin"
"$dart" compile exe bin/iphonesim.dart -o "$bin/iphonesim"
echo "Installed $bin/iphonesim"
case ":$PATH:" in
  *":$bin:"*) ;;
  *) echo "Note: $bin is not on your PATH." ;;
esac
