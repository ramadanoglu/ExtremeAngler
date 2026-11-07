#!/usr/bin/env bash
# Extreme Angler build script.
#
#   bash build.sh            bundle the modules into one file, syntax-check it and
#                            install it into your WoW Forever AddOns folder
#   bash build.sh package    create dist/ExtremeAngler-<version>.zip for CurseForge
#
# Set WOW_ADDONS to your AddOns folder if it isn't the default below.
# The syntax check needs Node.js and `npm install` inside .tools/.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDONS="${WOW_ADDONS:-/c/Games/World of Warcraft/_forever_/Interface/AddOns}"
CHECK="node $ROOT/.tools/check.js"
NAME=ExtremeAngler
SRC="$ROOT/$NAME"
MODULES="Core Gear Stats UI Toast Options"

package() {
  local version
  version=$(sed -n 's/^## Version: *//p' "$SRC/$NAME.toc" | tr -d '\r')
  for f in $MODULES; do $CHECK "$SRC/$f.lua"; done
  mkdir -p "$ROOT/dist"
  local zip="$ROOT/dist/$NAME-$version.zip"
  # python's zipfile writes forward-slash paths (Windows PowerShell 5.1 doesn't)
  python - "$SRC" "$zip" "$NAME" <<'EOF'
import os, sys, zipfile
src, out, name = sys.argv[1:4]
keep = lambda f: f.endswith(('.lua', '.toc')) or f in ('LICENSE', 'CHANGELOG.md', 'README.md')
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for f in sorted(filter(keep, os.listdir(src))):
        z.write(os.path.join(src, f), name + '/' + f)
print('packaged', out)
EOF
}

install() {
  # One bundled file, so /reload picks up changes without restarting the game
  local out dst="$ADDONS/$NAME"
  out="$(mktemp)"
  echo "-- $NAME (bundled build of: $MODULES)" > "$out"
  for f in $MODULES; do
    printf '\n-- ===== %s.lua =====\ndo\n' "$f" >> "$out"
    cat "$SRC/$f.lua" >> "$out"
    printf '\nend\n' >> "$out"
  done
  $CHECK "$out"
  mkdir -p "$dst"
  rm -f "$dst"/*.lua
  cp "$out" "$dst/$NAME.lua"
  sed "s/^Core.lua\$/$NAME.lua/; /^\\(Gear\\|Stats\\|UI\\|Toast\\|Options\\)\\.lua\$/d" "$SRC/$NAME.toc" > "$dst/$NAME.toc"
  rm -f "$out"
  echo "$NAME: syntax OK, installed to $dst"
}

case "$1" in
  package) package ;;
  *) install ;;
esac
