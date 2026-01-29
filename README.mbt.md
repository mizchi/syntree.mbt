# syntree.mbt

Lezer-inspired incremental syntax tree and highlighting toolkit for MoonBit.

## Packages

- `mizchi/syntree.mbt/lezer` - core tree, cursor, and highlight APIs
- `mizchi/syntree.mbt/lezer/<lang>` - language tokenizers + highlighters (typescript, moonbit, json, html, css, bash, rust, mdx)
- `mizchi/syntree.mbt/lezer/shiki` - Shiki-style HTML rendering
- `mizchi/syntree.mbt/lezer_api` - JS exports for the bundled highlighters

## JS usage

`js/lezer_api.js` wraps the MoonBit JS build output and exposes convenience helpers.

```js
import { highlight, highlightTypeScript } from "./js/lezer_api.js";

const html = highlight("const x = 1", "ts");
const html2 = highlightTypeScript("const x = 1");
```

## Development

```bash
just check
just test
just bench
just info
```
