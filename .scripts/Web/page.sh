#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Lays an application's Web page out beside its built module: index.html, the
# relay stateui-web.js and its look stateui-web.css, the module <App>Web.wasm,
# what the head's Page folder adds and the application's pictures in Images.
#
# USAGE:
#   page.sh <app-dir> <products> <site>
#
#   app-dir   the application's folder: Platforms/Web/Page, Resources/Images
#   products  the folder the build wrote <App>Web.wasm in
#   site      the folder the page is laid in, made anew
#
# The head's Page folder - <app-dir>/Platforms/Web/Page - adds to the page:
#   *.js       laid beside it, each loaded before the application starts;
#   head.html  written into its head as it stands: a description, the address
#              it is found at, what a shared link shows. A <title> in it names
#              the page, which is otherwise named after the application.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checkout="$(cd "$here/../.." && pwd)"

app_dir="${1:?USAGE: $0 <app-dir> <products> <site>}"
products="${2:?USAGE: $0 <app-dir> <products> <site>}"
site="${3:?USAGE: $0 <app-dir> <products> <site>}"

app_dir="$(cd "$app_dir" && pwd)"
application="$(basename "$app_dir")"
product="${application}Web"
library="$checkout/lib/StateUI/StateUI.Web/JavaScript"
page="$app_dir/Platforms/Web/Page"

rm -rf "$site"
mkdir -p "$site"
cp "$products/$product.wasm" "$site/"
cp "$library/stateui-web.js" "$library/stateui-web.css" "$site/"
stamp="$(date +%s)"

# The application's own scripts - the custom elements its controls show - beside the page, each loaded before it.
scripts=""
if [[ -d "$page" ]]; then
  for script in "$page/"*.js; do
    [[ -f "$script" ]] || continue
    cp "$script" "$site/"
    scripts+="<script type=\"module\" src=\"./$(basename "$script")?v=$stamp\"></script>"
  done
fi

# The head's own head stands in the page as written: awk copies it line for line, where a substitution would
# read its characters as its own.
head="$page/head.html"
[[ -f "$head" ]] || head=/dev/null
named=0
grep -qi '<title' "$head" && named=1
sed -e "s/{{application}}/$application/g" -e "s/{{module}}/$product.wasm/g" -e "s/{{stamp}}/$stamp/g" \
  -e "s#{{scripts}}#$scripts#" \
  "$library/index.html" |
  awk -v head="$head" -v named="$named" -v application="$application" '
    $0 == "{{head}}" {
      if (!named) print "<title>" application "</title>"
      while ((getline line < head) > 0) print line
      next
    }
    { print }' > "$site/index.html"

if [[ -d "$app_dir/Resources/Images" ]]; then
  mkdir -p "$site/Images"
  cp -R "$app_dir/Resources/Images/." "$site/Images/"
fi
