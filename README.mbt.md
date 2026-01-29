# syntree.mbt

Incremental syntax tree and highlighting toolkit for MoonBit.

## Packages

- `mizchi/syntree` - core tree, cursor, and highlight APIs
- `mizchi/syntree/<lang>` - language tokenizers + highlighters (typescript, moonbit, json, html, css, bash, rust, mdx)
- `mizchi/syntree/highlight` - HTML rendering with inline styles
- `mizchi/syntree/syntree_api` - JS exports for the bundled highlighters

## JS usage

`js/syntree_api.js` wraps the MoonBit JS build output and exposes convenience helpers.

```js
import { highlight, highlightTypeScript } from "./js/syntree_api.js";

const html = highlight("const x = 1", "ts");
const html2 = highlightTypeScript("const x = 1");
```

## Reference implementation

- Lezer: https://lezer.codemirror.net/

## Development

```bash
just check
just test
just bench
just info
```
