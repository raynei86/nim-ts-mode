# nim-ts-mode - An Emacs major mode for Nim using tree-sitter


## Installation

Clone this repository into your load-path, so Emacs can find the package.
This package is self-contained and requires Emacs 29+ with the Nim tree-sitter parser installed.

```elisp
(setq treesit-language-source-alist
      '((nim "https://github.com/alaviss/tree-sitter-nim")))

(add-to-list 'auto-mode-alist '("\\.nim\\'" . nim-ts-mode))

(require 'nim-ts-mode)

;; if you want to get LSP-Mode working you also need to set the following
;; in addition to the configuration needed for lsp-mode
(with-eval-after-load 'lsp-mode
  (add-to-list 'lsp-language-id-configuration
               '(nim-ts-mode . "nim")))
```

To install the `nim-tree-sitter` parser run `treesit-install-language-grammar` and select `nim`. You may need to have some build tools like gcc installed for this to work.

## Configuration

You can set `nim-ts-mode-indent-level` to the number of spaces that should be used for indentation. Also tree-sitter provides the ability to set the `treesit-font-lock-level` to a value from 1 to 3,
to controll how much different elements to highlight, with 3 highlighting the most elements.

## TODO

- [x] Make syntax highlighting work using tree-sitter
- [x] Provide simplified indentation mechanism
- [ ] Highlight HTML and Javscript parts in strings using their respective parsers
- [ ] Create package that auto-installs dependencies and sets up tree-sitter, etc.
- ~~[ ] Make indentation work using tree-sitter~~ question if this really is necessary


Feedback and pull-request are welcome.
