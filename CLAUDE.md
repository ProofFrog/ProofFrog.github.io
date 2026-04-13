# ProofFrog Website

This is the documentation website for [ProofFrog](https://github.com/ProofFrog/ProofFrog), a tool for verifying game-hopping cryptographic proofs. The site is published at https://prooffrog.github.io.

## Tech stack

- **Jekyll 4.4** static site generator with the **Just the Docs 0.12.0** theme
- **jekyll-katex** plugin for math rendering (use `{% katex %}...{% endkatex %}` blocks)
- **jekyll-redirect-from** plugin for URL redirects (via `redirect_from:` in front matter)
- Custom Rouge syntax highlighter for FrogLang DSL (`_plugins/rouge_prooffrog.rb`)
- Ruby gems managed via `Gemfile`

## Building locally

```bash
bundle install
bundle exec jekyll serve
```

## Content structure

- `manual/` — primary user-facing documentation
  - `installation.md` — installation guide (all platforms)
  - `tutorial/` — step-by-step getting started tutorials
  - `worked-examples/` — detailed worked proof examples
  - `language-reference/` — FrogLang language reference
  - `cli-reference.md`, `web-editor.md`, `editor-plugins.md`, etc.
- `researchers/` — content aimed at researchers (engine internals, publications, soundness)
- `examples.md` — catalogue of supported proof examples
- `_data/linear_sequence.yml` — ordered page sequence for the linear "Getting Started" navigation path

## Page conventions

- All content pages are Markdown with YAML front matter
- Two layouts: `default` (standard) and `linear` (sequential reading path with prev/next links)
- Pages using `layout: linear` must also appear in `_data/linear_sequence.yml`
- Use `{: .no_toc }` after the top-level heading, then the TOC block:
  ```
  - TOC
  {:toc}
  ```
- Internal links use Jekyll's `{% link path/to/file.md %}` tag
- Callout blocks use Just the Docs IAL syntax: `{: .note }`, `{: .warning }`, `{: .important }`, `{: .highlight }`, `{: .new }`
- Code blocks should use appropriate language identifiers (`bash`, `powershell`, `fish`, etc.)
- FrogLang code blocks use the custom `prooffrog` language identifier

## Navigation hierarchy

Pages declare their position via front matter: `parent`, `grand_parent`, `nav_order`, `has_children`. The Manual section is the main nav parent; subsections (Tutorial, Language Reference, etc.) are children of Manual.
