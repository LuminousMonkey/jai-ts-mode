;;; jai-ts-mode.el --- Major mode for editing Jai code using tree-sitter -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Mike Aldred

;; Author: Mike Aldred <mike.aldred@luminousmonkey.org>
;; URL: https://github.com/luminousmonkey/emacs-jai-mode
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, jai

;; This file is not part of GNU Emacs.

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; This package provides a major mode for editing code in the Jai
;; programming language using the tree-sitter parsing library.
;; It offers syntax highlighting, indentation, and various editing
;; features specific to Jai.

;;; Code:
;; Dependencies
(eval-when-compile
  (declare-function treesit-ready-p "treesit")
  (declare-function treesit-parser-create "treesit")
  (declare-function treesit-font-lock-rules "treesit")
  (declare-function treesit-major-mode-setup "treesit"))

(require 'treesit nil t)
(require 'prog-mode)

(unless (featurep 'treesit)
  (error "Treesit not available in this Emacs; use Emacs 29.1 or newer"))

;; Customization options
(defgroup jai-ts-mode nil
  "Major mode for editing Jai code using tree-sitter."
  :group 'languages
  :prefix "jai-ts-")

;; Define face for uninitialized values (---)
(defface jai-uninitialized-face
  '((((background light)) :foreground "black" :background "#ffdddd" :weight bold)
    (((background dark)) :foreground "white" :background "#662222" :weight bold))
  "Face for the uninitialized value (---) in Jai."
  :group 'jai-ts-mode)

;; Define face for annotations (@Annotation)
(defface jai-annotation-face
  '((((background light)) :foreground "#7070ff" :weight bold)
    (((background dark)) :foreground "#9090ff" :weight bold))
  "Face for annotations (@xyz) in Jai."
  :group 'jai-ts-mode)

(defvar jai-ts-font-lock-rules
  '(
    :language jai
    :feature comment
    ([(comment) (block_comment)] @font-lock-comment-face)

    :language jai
    :feature directive
    ((compiler_directive) @font-lock-preprocessor-face)

    :language jai
    :feature number
    ([(integer) (float)] @font-lock-number-face)

    :language jai
    :feature string
    ([(string) (string_content)] @font-lock-string-face
     ;; Here string support
     (string_directive
      directive: "#string" @font-lock-preprocessor-face
      (heredoc_start) @font-lock-keyword-face
      (heredoc_body) @font-lock-string-face
      (heredoc_end) @font-lock-keyword-face))

    :language jai
    :feature constant
    ([(boolean) (null)] @font-lock-constant-face
     (uninitialized) @jai-uninitialized-face
     ;; Enum values with dot prefix (.OPTION_1)
     (member_expression "." (identifier) @font-lock-constant-face)
     ;; Regular constants (ALL_CAPS)
     ((identifier) @font-lock-constant-face
      (:match "^_*[A-Z][A-Z0-9_]*$" @font-lock-constant-face))
     ;; Enum declaration constants
     (enum_declaration "{" (identifier) @font-lock-constant-face))

    :language jai
    :feature type
    (;; Types in all contexts
     (types (identifier) @font-lock-type-face)

     ;; Array types - match identifier at end of array type expression
     (array_type (identifier) @font-lock-type-face)

     ;; Struct literals - type name
     (struct_literal (identifier) @font-lock-type-face)

     ;; Type declarations
     (struct_declaration (identifier) @font-lock-type-face)
     (enum_declaration (identifier) @font-lock-type-face)

     ;; Identifier used as type in various contexts
     (variable_declaration ":" (identifier) @font-lock-type-face)
     (parameter ":" (identifier) @font-lock-type-face))

    :language jai
    :feature variables
    (;; Variable declarations (including multi-variable)
     (variable_declaration
      (identifier) @font-lock-variable-name-face)

     ;; Assignment statements (left-hand side identifiers)
     (assignment_statement
      (identifier) @font-lock-variable-name-face)

     ;; Update statements (+=, -=, etc)
     (update_statement
      (identifier) @font-lock-variable-name-face)

     ;; Place directive
     (place_directive
      (identifier) @font-lock-variable-name-face)

     ;; Constants
     (const_declaration
      (identifier) @font-lock-constant-face)

     ;; Member expressions - simple approach
     (member_expression
      "." @font-lock-punctuation-face)

     ;; Just the leaves of member expressions (should be safe)
     (member_expression
      (identifier) @font-lock-variable-name-face)

     ;; Operators for all contexts
     [":" "="] @font-lock-operator-face)

    :language jai
    :feature procedure-name
    ((procedure_declaration
      name: (identifier) @font-lock-function-name-face))

    :language jai
    :feature procedure-parameter
    ((parameter
      name: (identifier) @font-lock-variable-name-face))

    :language jai
    :feature procedure-named-return
    ((named_return (identifier) @font-lock-variable-name-face))

    :language jai
    :feature return-type
    (;; Simple return type (like "float" in "-> float")
     (procedure_returns
      (returns
       (identifier_type
        type: (identifier) @font-lock-type-face))))

    :language jai
    :feature annotation
    ((note) @jai-annotation-face)

    ;; Missing keyword highlighting in font-lock-rules
    :language jai
    :feature keyword
    ([
      ;; Control flow keywords
      "if" "else" "then" "ifx" "case"
      "while" "for" "break" "continue" "return"

      ;; Type and structure keywords
      "struct" "union" "enum" "enum_flags"

      ;; Function modifiers
      "inline" "no_inline"

      ;; Other keywords
      "using" "remove" "defer" "cast" "xx" "push_context"
      ] @font-lock-keyword-face)
    ))

(defun jai-ts-setup ()
  "Setup for `jai-ts-mode'."
  (interactive)
  (setq-local treesit-font-lock-settings
              (apply #'treesit-font-lock-rules
                     jai-ts-font-lock-rules))
  (setq-local font-lock-defaults nil)
  (setq-local treesit-font-lock-feature-list
              '((comment directive annotation)
                (keyword type number string constant)
                (variables procedure-name procedure-parameter procedure-named-return return-type)))

  (setq-local treesit-font-lock-level 5)
  (treesit-major-mode-setup))

(defvar jai-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; Comments
    (modify-syntax-entry ?\/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)

    ;; Strings
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\' "\"" table)

    table))

;; Comment handling is now simplified and relies on syntax-ppss

;; Keymap for jai-ts-mode
(defvar jai-ts-mode-map
  (let ((map (make-sparse-keymap)))
    map)
  "Keymap for `jai-ts-mode'.")

;; Indentation rules for Jai using tree-sitter
(defvar jai-ts-indent-rules
  '((jai
     ((parent-is "source_file") parent-bol 0)

     ;; Block indentation - indent contents by 4 spaces
     ((node-is "}") parent-bol 0)
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((parent-is "block") parent-bol +4)

     ;; Struct/enum declaration indentation
     ((parent-is "struct_declaration") parent-bol +4)
     ((parent-is "enum_declaration") parent-bol +4)

     ;; If/else statements with blocks - indent the block contents
     ((and (parent-is "if_statement") (node-is "block")) parent-bol +4)
     ((and (parent-is "else_clause") (node-is "block")) parent-bol +4)

     ;; For braceless if/else - indent only direct consequence
     ((and (field-is "consequence") (not (node-is "block")) (not (node-is "if_statement")))
      parent-bol +4)

     ;; Case statement indentation
     ((parent-is "if_case_statement") parent-bol +4)
     ((parent-is "switch_case") parent-bol +4)

     ;; Default for other constructs
     (no-node parent-bol 0)))
  "Tree-sitter indentation rules for Jai mode.")

;; Advice to make prog-fill-reindent-defun do nothing outside of comments in Jai mode
(defun jai-ts--disable-fill-outside-comments (orig-fun &rest args)
  "Make `prog-fill-reindent-defun' do nothing outside of comments in Jai mode.
ORIG-FUN is the original function and ARGS are its arguments."
  (if (and (eq major-mode 'jai-ts-mode)  ; Only affect Jai mode
           (not (nth 8 (syntax-ppss)))) ; Not in a comment or string according to syntax tables
      ;; Not in a comment - do nothing
      nil
    ;; Otherwise, call the original function
    (apply orig-fun args)))

;; Mode hook functions
(defun jai-ts-mode-setup ()
  "Setup function called when entering `jai-ts-mode'."
  ;; Add the advice
  (advice-add 'prog-fill-reindent-defun :around #'jai-ts--disable-fill-outside-comments))

(defun jai-ts-mode-teardown ()
  "Teardown function called when exiting `jai-ts-mode'."
  ;; Remove the advice
  (advice-remove 'prog-fill-reindent-defun #'jai-ts--disable-fill-outside-comments))

;;;###autoload
(define-derived-mode jai-ts-mode prog-mode "Jai[ts]"
  "Major mode for editing Jai programming language code.
Uses tree-sitter for syntax parsing and provides:
- Syntax highlighting
- Proper indentation
- Comment-aware editing features"
  :syntax-table jai-mode-syntax-table
  :keymap jai-ts-mode-map
  :group 'jai-ts-mode

  ;; Comments
  ;; Configure how comments are handled
  (setq-local comment-start "// ")
  (setq-local comment-end "")

  ;; Set up indentation using tree-sitter rules
  (when (boundp 'treesit-simple-indent-rules)
    (setq-local treesit-simple-indent-rules jai-ts-indent-rules)
    (when (fboundp 'treesit-indent-line)
      (setq-local indent-line-function #'treesit-indent-line)))

  ;; Create tree-sitter parser if language is available
  (when (treesit-ready-p 'jai)
    (treesit-parser-create 'jai)
    (jai-ts-setup))

  ;; Run the setup function
  (jai-ts-mode-setup)

  ;; Add the teardown function to the mode hook
  (add-hook 'change-major-mode-hook #'jai-ts-mode-teardown nil t))

(add-to-list 'auto-mode-alist '("\\.jai\\'" . jai-ts-mode))

(provide 'jai-ts-mode)

;;; jai-ts-mode.el ends here
