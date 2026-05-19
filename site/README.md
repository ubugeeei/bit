# bit — documentation site

The static documentation site for **bit**. Deployed to GitHub Pages from this
folder. No build step: every page is hand-authored HTML referencing shared
CSS and a tiny vanilla JS syntax highlighter.

## Layout

```
site/
├── index.html              ← landing page
├── learn/                  ← Learning Guide
│   ├── index.html
│   ├── install.html
│   ├── first-commit.html
│   └── distributed.html
├── reference/              ← Reference
│   ├── index.html
│   ├── cli.html
│   ├── library.html
│   └── env.html
├── assets/
│   ├── tokens.css          ← brand design tokens (copied from /brand)
│   ├── site.css            ← site-level layout + components
│   ├── syntax.js           ← MoonBit / bash syntax highlighter
│   ├── site.js             ← nav toggle, copy buttons
│   └── img/                ← logo, wordmark, lockups (copied from /brand)
└── .nojekyll               ← tell GitHub Pages not to run Jekyll
```

## Preview locally

Just open `site/index.html` in your browser. All paths are relative, so it
works straight off the filesystem. For a real HTTP server (recommended — the
clipboard API needs a secure context):

```sh
python3 -m http.server -d site 8080
# open http://localhost:8080
```

## Deploy

Pushed automatically by [`.github/workflows/pages.yml`](../.github/workflows/pages.yml)
on every push to `main` or `brand` that touches `site/` or `brand/`.

The workflow re-syncs brand assets (tokens.css + logo SVGs) from `brand/`
into `site/assets/` before uploading, so the source of truth stays in
`brand/` and the site is always in lockstep.

To enable: in the repo's **Settings → Pages**, set the source to
**GitHub Actions**. The workflow handles the rest.

## Updating brand assets

Don't edit `site/assets/tokens.css` or `site/assets/img/*.svg` directly —
edit the originals in [`brand/`](../brand/) and re-sync:

```sh
cp brand/tokens/tokens.css site/assets/tokens.css
cp brand/logo/*.svg site/assets/img/
```

The Pages workflow does this automatically on every deploy.

## Adding pages

1. Create the HTML file using one of the existing pages as a template
   (`learn/install.html` is a good starting point for a guide chapter,
   `reference/env.html` for a reference page).
2. Add the page to the relevant side navigation (`<aside class="side">`)
   in every sibling page so navigation stays consistent.
3. Add it to the index TOC (`learn/index.html` or `reference/index.html`).
4. Wire prev/next pager links at the bottom of the article.

## MoonBit code highlighting

Wrap MoonBit snippets in:

```html
<div class="codeblock">
  <div class="codeblock__bar"><span class="lang">// moonbit</span><button class="codeblock__copy">copy</button></div>
  <pre><code data-lang="moonbit">let x = 42</code></pre>
</div>
```

Supported `data-lang` values: `moonbit`, `mbt`, `bash`, `sh`. Anything else
renders as plain text.
