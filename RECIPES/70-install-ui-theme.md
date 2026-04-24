# Install a UI design kit

The starter doesn't ship a visual design system by itself — Phoenix's
default Tailwind + DaisyUI works fine for prototyping but looks generic.
Two curated zero-dependency kits from the companion repo let you pick a
coherent aesthetic in 30 seconds.

Companion repo: https://github.com/ashishbishnoi18/ui-design-kits

| Kit | Vibe | Components | Bundle size (min) |
|---|---|---|---|
| **`devkit`** | Modern, dark-first, Vercel/Stripe-ish | 156 | ~270 KB CSS + ~200 KB JS |
| **`neobrutalism`** | Bold brutalist, thick borders, saturated colors | 150+ | Similar |

Both are **pure CSS + vanilla JS** — no build step, no Tailwind
dependency, no React/Vue. Drop them in, reference the classes.

## Install

```bash
# DevKit:
scripts/install-theme.sh devkit

# Neobrutalism:
scripts/install-theme.sh neobrutalism
```

What the script does:

1. Downloads the latest `main` tarball of `ui-design-kits`
2. Extracts the chosen kit's `dist/` bundle to
   `priv/static/themes/<theme>/`
3. Copies the kit's `AGENT.md` (the component vocabulary doc) next to
   the bundle so AI agents can read it
4. Writes `.theme` at the repo root as the "active theme" marker
5. Prints the two edits you still need to make (below)

`priv/static/themes/` and `.theme` are **gitignored** — re-run
`scripts/install-theme.sh $(cat .theme)` on any fresh clone to
regenerate the bundle.

## Two manual edits (AI agent does these)

### 1. Allow the `themes` static path

```elixir
# lib/saas_starter_web.ex
def static_paths, do: ~w(assets fonts images themes favicon.ico robots.txt)
```

Add `themes` to that list. Without it, Phoenix's `Plug.Static` won't
serve the files and you'll get 404s.

### 2. Link the stylesheet + script in the root layout

```heex
<%!-- lib/saas_starter_web/components/layouts/root.html.heex, inside <head> --%>

<%!-- For devkit: --%>
<link phx-track-static rel="stylesheet" href={~p"/themes/devkit/devkit.min.css"} />
<script defer phx-track-static src={~p"/themes/devkit/devkit.min.js"}></script>

<%!-- For neobrutalism: --%>
<link phx-track-static rel="stylesheet" href={~p"/themes/neobrutalism/nb-ui-kit.min.css"} />
<script defer phx-track-static src={~p"/themes/neobrutalism/nb-ui-kit.min.js"}></script>
```

## Using the kit in LiveViews

The kit's `AGENT.md` lives at `priv/static/themes/<theme>/AGENT.md`.
Read it — that's the full class vocabulary. Quick examples:

**DevKit:**
```heex
<button class="dk-btn dk-btn--primary">Click me</button>
<div class="dk-card">
  <div class="dk-card__header">Title</div>
  <div class="dk-card__body">Body</div>
</div>
```

**Neobrutalism:**
```heex
<button class="nb-btn nb-btn--primary">Click me</button>
<div class="nb-card">
  <h3 class="nb-card__title">Title</h3>
  <p>Body</p>
</div>
```

Exact class names depend on each kit — trust the AGENT.md.

## Mixing with Tailwind

These kits ship their own design tokens (colors, spacing, typography),
so mixing Tailwind utilities in the same component usually looks
inconsistent. Three reasonable patterns:

1. **Kit only, strip Tailwind** — remove the Tailwind import from
   `assets/css/app.css`. Smallest CSS bundle, tightest design
   consistency. Use the kit's layout utilities instead.
2. **Kit for components + Tailwind for layout** — keep Tailwind for
   flex/grid/spacing utilities (`flex`, `gap-4`, `mt-8`) and use the
   kit's classes for buttons/cards/forms. Works well for most apps.
3. **Both, freely mixed** — if you're careful. Risk: inconsistent
   visuals.

Default: option 2.

## Switching themes

Re-run the script with the other arg:

```bash
scripts/install-theme.sh neobrutalism
```

The script removes the previous theme directory and installs the new
one. You'll need to update the `<link>` + `<script>` hrefs in
`root.html.heex` (the filename changes: `devkit.min.css` →
`nb-ui-kit.min.css`).

## Uninstalling

```bash
rm -rf priv/static/themes/ .theme
```

Then remove the `<link>` + `<script>` from `root.html.heex` and
`themes` from `static_paths()`. You're back to vanilla Phoenix +
Tailwind.

## Previewing before committing

Each kit ships a `pages/` directory with demo HTML files showing every
component. To preview:

```bash
# One-off: browse the GitHub pages
open https://github.com/ashishbishnoi18/ui-design-kits/tree/main/devkit/pages
open https://github.com/ashishbishnoi18/ui-design-kits/tree/main/neobrutalism-ui-kit/pages
```

Click through `landing.html`, `dashboard.html`, `login.html`, etc. to
see the aesthetic before committing to one.
