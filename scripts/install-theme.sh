#!/usr/bin/env bash
# install-theme.sh — pick a UI design kit from the companion repo
# (github.com/ashishbishnoi18/ui-design-kits) and install its bundle
# into priv/static/themes/<theme>/. Re-running replaces the active
# theme.
#
# Usage:
#   scripts/install-theme.sh devkit          # DevKit (156 components, dark)
#   scripts/install-theme.sh neobrutalism    # Neobrutalism (150+, bold)
#
# After install, the script prints the exact HEEx snippet to add to
# root.html.heex and the static_paths() edit. The agent does those two
# edits; this script only moves files.
set -euo pipefail

theme="${1:-}"

case "$theme" in
  devkit)
    kit_dir="devkit"
    css_file="devkit.min.css"
    js_file="devkit.min.js"
    label="DevKit (156 components, dark theme)"
    ;;
  neobrutalism|neobrutalism-ui-kit|nb)
    theme="neobrutalism"
    kit_dir="neobrutalism-ui-kit"
    css_file="nb-ui-kit.min.css"
    js_file="nb-ui-kit.min.js"
    label="Neobrutalism UI Kit (150+ components, bold brutalist)"
    ;;
  "")
    cat <<'EOF' >&2
Usage: scripts/install-theme.sh <devkit|neobrutalism>

Installs one of the two UI kits from
github.com/ashishbishnoi18/ui-design-kits into priv/static/themes/.

Kits are pure CSS + vanilla JS (zero build deps). The minified bundle
is copied plus the kit's AGENT.md so an AI agent can read the
component vocabulary.

Re-running with a different kit replaces the active theme.
EOF
    exit 1
    ;;
  *)
    echo "error: unknown theme '$theme' (expected: devkit | neobrutalism)" >&2
    exit 2
    ;;
esac

repo="ashishbishnoi18/ui-design-kits"
root="$(git rev-parse --show-toplevel)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "==> Downloading ${repo}@main..."
curl -fsSL "https://github.com/${repo}/archive/refs/heads/main.tar.gz" \
  | tar -xz -C "$tmpdir" --strip-components=1

src="$tmpdir/${kit_dir}"
if [[ ! -d "$src/dist" ]]; then
  echo "error: $src/dist not found in fetched tarball" >&2
  exit 3
fi

dest_root="${root}/priv/static/themes"
dest="${dest_root}/${theme}"

echo "==> Removing any previously installed theme from priv/static/themes/..."
rm -rf "$dest_root"
mkdir -p "$dest"

echo "==> Installing ${label} to ${dest#"$root"/}"
cp -r "$src/dist/." "$dest/"
if [[ -f "$src/AGENT.md" ]]; then
  cp "$src/AGENT.md" "$dest/AGENT.md"
fi

# Record the choice for future reference.
printf '%s\n' "$theme" > "${root}/.theme"

echo
cat <<EOF
✓ Theme installed: ${theme}

Files under priv/static/themes/${theme}/:
  - ${css_file}
  - ${js_file}
  - AGENT.md  (component vocabulary for this kit)

Two edits remain — the agent (or you) completes these:

(1) Add 'themes' to the static paths allowlist in
    lib/saas_starter_web.ex:

    def static_paths, do: ~w(assets fonts images themes favicon.ico robots.txt)

(2) Link the stylesheet + script in the root layout
    lib/saas_starter_web/components/layouts/root.html.heex,
    inside <head>:

    <link phx-track-static rel="stylesheet" href={~p"/themes/${theme}/${css_file}"} />
    <script defer phx-track-static src={~p"/themes/${theme}/${js_file}"}></script>

(3) Read priv/static/themes/${theme}/AGENT.md for the component
    class vocabulary, then use it in your LiveView templates.

(4) Commit:
    scripts/ai-commit.sh "Install UI theme: ${theme}"
EOF
