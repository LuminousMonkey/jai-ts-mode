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

(defun jai-ts-setup ()
  "Setup for `jai-ts-mode'."
  (interactive)
  (setq-local treesit-font-lock-settings
              (treesit-font-lock-rules
               ;; Comments
               :language 'jai
               :feature 'comment
               '((comment) @font-lock-comment-face
                 (block_comment) @font-lock-comment-face)

               ;; Compiler directives (#import, #load, #run, #scope_file, etc)
               :language 'jai
               :feature 'directive
               '((compiler_directive) @font-lock-preprocessor-face
                 (import directive: (compiler_directive) @font-lock-preprocessor-face)
                 (load directive: (compiler_directive) @font-lock-preprocessor-face)
                 (run_or_insert_expression (compiler_directive) @font-lock-preprocessor-face)
                 (string_directive) @font-lock-preprocessor-face
                 (heredoc_start) @font-lock-preprocessor-face
                 (heredoc_end) @font-lock-preprocessor-face
                 (heredoc_body) @font-lock-string-face)

               ;; Numbers and character literals
               :language 'jai
               :feature 'number
               '((integer) @font-lock-number-face
                 (float) @font-lock-number-face
                 (char_string) @font-lock-number-face)

               ;; Strings
               :language 'jai
               :feature 'string
               '((string) @font-lock-string-face
                 (string_content) @font-lock-string-face
                 (escape_sequence) @font-lock-escape-face)

               ;; Constants (literals, enum fields, const declarations)
               :language 'jai
               :feature 'constant
               '((boolean) @font-lock-constant-face
                 (null) @font-lock-constant-face
                 (uninitialized) @jai-uninitialized-face
                 (enum_field (identifier) @font-lock-constant-face)
                 (const_declaration name: (identifier) @font-lock-constant-face))

               ;; Types (type annotations, struct/enum names, cast targets)
               :language 'jai
               :feature 'type
               '((types (identifier) @font-lock-type-face)
                 (array_type type: (identifier) @font-lock-type-face)
                 (pointer_type (types (identifier) @font-lock-type-face))
                 (struct_literal (identifier) @font-lock-type-face)
                 (struct_declaration name: (identifier) @font-lock-type-face)
                 (enum_declaration name: (identifier) @font-lock-type-face)
                 (cast_expression (types (identifier) @font-lock-type-face))
                 (identifier_type type: (identifier) @font-lock-type-face))

               ;; Function definitions and calls
               :language 'jai
               :feature 'function
               '((procedure_declaration name: (identifier) @font-lock-function-name-face)
                 (call_expression function: (identifier) @font-lock-function-call-face))

               ;; Variables (declarations, parameters, loop variables)
               :language 'jai
               :feature 'variable
               '((variable_declaration name: (identifier) @font-lock-variable-name-face)
                 (parameter name: (identifier) @font-lock-variable-name-face)
                 (named_return (identifier) @font-lock-variable-name-face)
                 (for_statement value: (identifier) @font-lock-variable-name-face)
                 (assignment_statement (identifier) @font-lock-variable-name-face))

               ;; Keywords
               :language 'jai
               :feature 'keyword
               '(["if" "else" "then" "ifx" "case"
                  "while" "for" "break" "continue" "return"
                  "struct" "union" "enum" "enum_flags"
                  "inline" "no_inline"
                  "using" "remove" "defer" "cast" "xx" "push_context"] @font-lock-keyword-face)

               ;; Annotations (@notes)
               :language 'jai
               :feature 'annotation
               '((note) @jai-annotation-face)))

  (setq-local font-lock-defaults nil)
  (setq-local treesit-font-lock-feature-list
              '((comment directive)
                (keyword string number)
                (type constant function variable annotation)))

  (setq-local treesit-font-lock-level 4)
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
