;;; nim-ts-mode.el --- An Emacs major mode for the Nim language using tree-sitter. -*- lexical-binding: t -*-

;; Copyright (C) 2024 Tobias Heinlein

;; Author: Tobias Heinlein <niontrix@mailbox.org>
;; URL: https://github.com/niontrix/nim-ts-mode
;; Maintainer: Tobias Heinlein <niontrix@mailbox.org>
;; Created: 01 Feb 2024
;; Version: 0.1.0
;; Keywords: convenience, editing, nim, highlighting, tools

;; This file is not part of GNU Emacs.

;;; License:

;; MIT License

;; Copyright (c) [2024] [Tobias Heinlein]

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

(require 'treesit)

(defgroup nim-ts nil
  "Major mode for the Nim language using tree-sitter."
  :group 'languages)

(defcustom nim-ts-mode-indent-level 2
  "Number of spaces to indent Nim code."
  :type 'integer
  :safe 'integerp
  :group 'nim-ts)

(defvar nim-ts-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?# "<" table)
    (modify-syntax-entry ?\n ">" table)
    (modify-syntax-entry ?\" "\"" table)
    table)
  "Syntax table for `nim-ts-mode`.")

(defvar nim-ts-mode--syntax-propertize-function
  (syntax-propertize-rules
   ("#\\[" (0 "< b"))
   ("\\]#" (0 "> b")))
  "Syntax propertize rules for Nim block comments.")

(defvar nim-ts-font-lock-rules
  '(;; SPDX-FileCopyrightText: 2023 Leorize <leorize+oss@disroot.org>
    ;; SPDX-License-Identifier: MPL-2.0

    ;; Punctuations
    :feature delimiter
    :language nim
    :override t
    (([ "." ";" "," ":" ] @font-lock-delimiter-face)
     ([ "(" ")" "[" "]" "{" "}" "{." ".}" ] @font-lock-bracket-face))

    ;; Special
    :feature special
    :language nim
    :override t
    ((blank_identifier) @font-lock-builtin-face)

    ;; Calls
    :feature call
    :language nim
    :override t
    ((call
      function: [
                 (identifier) @font-lock-function-call-face
                 (dot_expression
                  right: (identifier) @font-lock-function-call-face)
                 ])
     (generalized_string
      function: [
                 (identifier) @font-lock-function-call-face
                 (dot_expression
                  right: (identifier) @font-lock-function-call-face)
                 ]))

    ;; Declarations
    :feature declaration
    :language nim
    :override t
    (
     (type_symbol_declaration
      name: [
             (identifier) @font-lock-type-face
             (accent_quoted (identifier) @font-lock-type-face)
             (exported_symbol
              [
               (identifier)
               (accent_quoted (identifier))
               ] @font-lock-type-face
              "*" @font-lock-operator-face)
             ])
     (proc_declaration name: (_) @font-lock-function-name-face)
     (func_declaration name: (_) @font-lock-function-name-face)
     (converter_declaration name: (_) @font-lock-function-name-face)
     (method_declaration name: (_) @font-lock-function-name-face)
     (iterator_declaration name: (_) @font-lock-function-name-face)
     (template_declaration name: (_) @font-lock-preprocessor-face)
     (macro_declaration name: (_) @font-lock-preprocessor-face)
     (parameter_declaration
      (symbol_declaration_list
       (symbol_declaration name: (_) @font-lock-variable-name-face)))
     (symbol_declaration name: (_) @font-lock-variable-name-face)
     (_ "=" @font-lock-delimiter-face [body: (_) value: (_)])
     (_
      [
       type: [
              (type_expression (identifier))
              (type_expression (accent_quoted (identifier)))
              ] @font-lock-type-face
       ;; TODO investigate if there can really be a return_type: node, because I haven't seen one up tu this point
       return_type: [
                     (type_expression (identifier))
                     (type_expression (accent_quoted (identifier)))
                     ] @font-lock-type-face
       ])
     ;; highlight generic types
     (type_expression (bracket_expression left: (identifier) @font-lock-type-face
                                          right: (argument_list (identifier) @font-lock-type-face)))
     )

    ;; Exceptions
    :feature exception
    :language nim
    :override t
    (([
       "try"
       "except"
       "finally"
       "raise"
       ] @font-lock-keyword-face)

     (except_branch values: (expression_list
                             [
                              (identifier) @font-lock-type-face
                              (infix_expression
                               left: (identifier) @font-lock-type-face
                               operator: "as"
                               right: (identifier) @font-lock-variable-name-face)
                              ])))

    ;; Expressions
    :feature expression
    :language nim
    :override t
    ((dot_expression
      right: (identifier) @font-lock-property-use-face))

    ;; Literal/comments
    :feature literal_comment
    :language nim
    :override t
    (([
       (comment)
       (block_comment)
       ] @font-lock-comment-face)

     ([
       (documentation_comment)
       (block_documentation_comment)
       ] @font-lock-doc-face)

     ((interpreted_string_literal) @font-lock-string-face)
     ((long_string_literal) @font-lock-string-face)
     ((raw_string_literal) @font-lock-string-face)
     ((generalized_string) @font-lock-string-face)
     ((char_literal) @font-lock-string-face)
     ((escape_sequence) @font-lock-escape-face)
     ((integer_literal) @font-lock-number-face)
     ((float_literal) @font-lock-number-face)
     ((custom_numeric_literal) @font-lock-number-face)
     ((nil_literal) @font-lock-constant-face)

     ;; string interpolation needs to added to the parser
     ;; ((string) @python-face--treesit-fontify-string
     ;;  (interpolation ["{" "}"] @font-face-lock-misc-punctuation-face))
     )

    ;; Keyword
    :feature keyword
    :language nim
    :override t
    (([
      "if"
      "when"
      "case"
      "elif"
      "else"
      ] @font-lock-keyword-face)

     (of_branch "of" @font-lock-keyword-face)
     ([
       "import"
       "include"
       "export"
       ] @font-lock-keyword-face)

     (import_from_statement "from" @font-lock-keyword-face)
     (except_clause "except" @font-lock-keyword-face)

     ([
      "for"
      "while"
      "continue"
      "break"
      ] @font-lock-keyword-face)

     (for "in" @font-lock-keyword-face)
     ([
       "macro"
       "template"
       "using"
       "const"
       "let"
       "var"
       "asm"
       "bind"
       "block"
       "concept"
       "defer"
       "discard"
       "distinct"
       "do"
       "end"
       "enum"
       "interface"
       "mixin"
       "nil"
       "object"
       "out"
       "ptr"
       "ref"
       "static"
       "tuple"
       "type"
       ] @font-lock-keyword-face)

     ([
       "proc"
       "func"
       "method"
       "converter"
       "iterator"
       ] @font-lock-keyword-face)

     (proc_declaration "proc" @font-lock-keyword-face)
     (func_declaration "func" @font-lock-keyword-face)
     (method_declaration "method" @font-lock-keyword-face)
     (converter_declaration "converter" @font-lock-keyword-face)
     (iterator_declaration "iterator" @font-lock-keyword-face)
     (macro_declaration "macro" @font-lock-keyword-face)
     (template_declaration "template" @font-lock-keyword-face)
     (const_section "const" @font-lock-keyword-face)
     (let_section "let" @font-lock-keyword-face)
     (var_section "var" @font-lock-keyword-face)
     (using_section "using" @font-lock-keyword-face)
     (type_section "type" @font-lock-keyword-face)

     ([
       "and"
       "or"
       "xor"
       "not"
       "addr"
       "div"
       "mod"
       "shl"
       "shr"
       "from"
       "as"
       "of"
       "in"
       "notin"
       "is"
       "isnot"
       "cast"
       ] @font-lock-operator-face)

     ;; true and false are missing as builtin constants and must be added in the parser lib
     ((identifier) @font-lock-constant-face
      (:match "\\_<\\(true\\|false\\)\\_>" @font-lock-constant-face))

     ((identifier) @font-lock-keyword-face
      (:match "\\_<\\(end\\|interface\\)\\_>" @font-lock-keyword-face))

     ([
       "return"
       "yield"
       ] @font-lock-keyword-face)
    )

    ;; Operators
    :feature operator
    :language nim
    ((infix_expression operator: _ @font-lock-operator-face)
     (prefix_expression operator: _ @font-lock-operator-face)
     [
      "="
      ] @font-lock-operator-face)
    )
  )


(defun nim-ts-mode--strip-comment (line)
  "Remove line comments from LINE."
  (replace-regexp-in-string "#.*\\'" "" line))

(defun nim-ts-mode--line-empty-p (line)
  "Return non-nil if LINE is blank."
  (string-match-p "\\`\\s-*\\'" line))

(defun nim-ts-mode--line-content ()
  "Return the current line without comments and trailing whitespace."
  (string-trim-right
   (nim-ts-mode--strip-comment
    (buffer-substring-no-properties (line-beginning-position) (line-end-position)))))

(defun nim-ts-mode--previous-nonblank-line ()
  "Return cons of (indent . line) for previous nonblank line."
  (save-excursion
    (let ((found nil)
          (indent 0)
          (line ""))
      (while (and (not found) (zerop (forward-line -1)))
        (setq line (nim-ts-mode--line-content))
        (unless (nim-ts-mode--line-empty-p line)
          (setq found t)
          (setq indent (current-indentation))))
      (when found
        (cons indent line)))))

(defun nim-ts-mode--line-opens-block-p (line)
  "Return non-nil if LINE opens a new block."
  (when line
    (or (string-match-p "[:=]\\s-*\\'" line)
        (string-match-p "\\`\\s-*\\(case\\|type\\|var\\|let\\|const\\)\\_>\\s-*\\'" line)
        (string-match-p "\\_<\\(object\\|enum\\|tuple\\|concept\\|interface\\)\\_>\\s-*\\'" line))))

(defun nim-ts-mode--line-dedent-p (line)
  "Return non-nil if LINE should dedent."
  (when line
    (string-match-p "\\`\\s-*\\(elif\\|else\\|except\\|finally\\|of\\|end\\)\\_>" line)))

(defun nim-ts-mode-indent-line ()
  "Indent current line as Nim code."
  (interactive)
  (let* ((current-line (nim-ts-mode--line-content))
         (previous (nim-ts-mode--previous-nonblank-line))
         (prev-indent (if previous (car previous) 0))
         (prev-line (if previous (cdr previous) ""))
         (dedent (nim-ts-mode--line-dedent-p current-line))
         (indent (cond
                  (dedent (max 0 (- prev-indent nim-ts-mode-indent-level)))
                  ((nim-ts-mode--line-opens-block-p prev-line)
                   (+ prev-indent nim-ts-mode-indent-level))
                  (t prev-indent)))
         (offset (- (current-column) (current-indentation))))
    (indent-line-to indent)
    (when (> offset 0)
      (move-to-column (+ indent offset)))))


;;;###autoload
(define-derived-mode nim-ts-mode prog-mode "Nim[ts]"
  "Major mode for editing Nim files with tree-sitter."
  :syntax-table nim-ts-mode-syntax-table

  (setq-local font-lock-defaults nil)
  (setq-local comment-start "# ")
  (setq-local comment-start-skip "#+\\s-*")
  (setq-local comment-end "")
  (setq-local comment-use-syntax t)
  (setq-local syntax-propertize-function nim-ts-mode--syntax-propertize-function)

  (electric-indent-mode 1)

  (if (treesit-ready-p 'nim)
      (progn
        (treesit-parser-create 'nim)
        (nim-ts-setup))
    (message "Tree-sitter grammar for Nim is not installed. Run `treesit-install-language-grammar`.")))


(defun nim-ts-setup ()
  "Setup tree-sitter for nim-ts-mode."

  ;; This handles font-locking
  (setq-local treesit-font-lock-settings
              (apply #'treesit-font-lock-rules
                     nim-ts-font-lock-rules))

  (setq-local indent-line-function #'nim-ts-mode-indent-line)

  (setq-local treesit-font-lock-feature-list
              '((comment keyword literal_comment)
                (declaration call expression)
                (exception delimiter special operator)
                ;; (delimiter special call declaration
                ;;  exception expression literal_comment keyword operator)
                ))

  (treesit-major-mode-setup))


(provide 'nim-ts-mode)
