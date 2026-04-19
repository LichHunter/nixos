;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Alexander Derevianko"
      user-mail-address "alexander0derevianko@gmail.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-unicode-font' -- for unicode glyphs
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
(setq doom-font (font-spec :family "Fira Code" :size 18)
      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 18))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-gruvbox)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type `relative)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

(general-auto-unbind-keys)
(map! :leader
      (:prefix ("m" . "my")
               "c" #'comment-dwim
               (:prefix ("d" . "dap")
                        "c" #'dap-java-run-test-class
                        "m" #'dap-java-run-test-method
                        "n" #'dap-next
                        "i" #'dap-step-in
                        "C" #'dap-continue
                        "k" #'dap-disconnect
                        "r" #'dap-debug-restart
                        (:prefix ("b" . "breakpoint")
                                 "a" #'dap-breakpoint-add
                                 "d" #'dap-breakpoint-delete
                                 "A" #'dap-breakpoint-delete-all
                                 )
                        (:prefix ("d" . "debug")
                                 "c" #'dap-java-debug-test-class
                                 "m" #'dap-java-debug-test-method
                                 )
                        )
               (:prefix ("l" . "lsp")
                        "j" #'lsp-jt-browser
                        "i" #'lsp-java-organize-imports
                        "r" #'lsp-rename
                        "g d" #'lsp-goto-type-definition
                        )
               )
      )

;; (setq lsp-java-format-settings-url "https://github.com/google/styleguide/blob/gh-pages/intellij-java-google-style.xml")

;; add map for lsp-jt-browser
;; + lsp-jt-browser
;; + dap-java-run-test-class
;; + dap-java-run-test-method

(setq git-commit-summary-max-length 1000)


(after! org
  (setq org-agenda-files '("~/org/agenda.org"
                           "~/nixos-dotfiles/todo.org"))
  (setq org-default-notes-file (expand-file-name "notes.org" org-directory)
        org-ellipsis " ▼ "
        org-superstar-headline-bullets-list '("◉" "●" "○" "◆" "●" "○" "◆")
        org-superstar-itembullet-alist '((?+ . ?➤) (?- . ?✦)) ; changes +/- symbols in item lists
        org-agenda-start-with-log-mode t
        org-log-done 'time
        org-log-into-drawer t
        org-hide-emphasis-markers t
        ;; ex. of org-link-abbrev-alist in action
        ;; [[arch-wiki:Name_of_Page][Description]]
        org-link-abbrev-alist    ; This overwrites the default Doom org-link-abbrev-list
        '(("google" . "http://www.google.com/search?q=")
          ("arch-wiki" . "https://wiki.archlinux.org/index.php/")
          ("ddg" . "https://duckduckgo.com/?q=")
          ("wiki" . "https://en.wikipedia.org/wiki/"))
        org-table-convert-region-max-lines 20000
        org-todo-keywords        ; This overwrites the default Doom org-todo-keywords
        '((sequence
           "TODO(t)"           ; A task that is ready to be tackled
           "INPROGRESS(i)"     ; A task that is in progress
           "WAIT(w)"           ; Something is holding up this task
           "|"                 ; The pipe necessary to separate "active" states and "inactive" states
           "DONE(d)"           ; Task has been completed
           "CANCELLED(c)" )))) ; Task has been cancelled

(after! lsp-java
  (require 'lsp-java-boot)
  (require 'dap-java)

  ;; Enable lenses
  (add-hook 'lsp-mode-hook #'lsp-lens-mode)
  (add-hook 'java-mode-hook #'lsp-java-boot-lens-mode)

  ;; =============================================================================
  ;; Smart Lombok Support
  ;; - Java 23+: Uses javac mode (Lombok works as annotation processor, no agent)
  ;; - Java <23: Queries Maven for Lombok version, downloads if needed, uses -javaagent
  ;; =============================================================================

  (defun my/maven-get-property (property)
    "Get a Maven property value from current project."
    (when-let ((pom-dir (locate-dominating-file default-directory "pom.xml")))
      (let ((default-directory pom-dir))
        (string-trim
         (shell-command-to-string
          (format "mvn help:evaluate -Dexpression=%s -q -DforceStdout 2>/dev/null" property))))))

  (defun my/get-project-java-version ()
    "Get Java version from project (maven.compiler.release or source)."
    (when-let ((pom-dir (locate-dominating-file default-directory "pom.xml")))
      (let* ((release (my/maven-get-property "maven.compiler.release"))
             (source (my/maven-get-property "maven.compiler.source"))
             (version-str (cond
                           ((and release (not (string-match-p "^\\$" release))) release)
                           ((and source (not (string-match-p "^\\$" source))) source)
                           (t nil))))
        (when version-str
          (string-to-number (replace-regexp-in-string "^1\\." "" version-str))))))

  (defvar my/lombok-cache (make-hash-table :test 'equal)
    "Cache of project-root -> lombok-jar-path.")

  (defun my/get-lombok-version-from-maven ()
    "Get Lombok version from Maven classpath."
    (when-let ((pom-dir (locate-dominating-file default-directory "pom.xml")))
      (let* ((default-directory pom-dir)
             (classpath (shell-command-to-string
                         "mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q 2>/dev/null")))
        (when (string-match "/lombok-\\([0-9][^/]*\\)\\.jar" classpath)
          (match-string 1 classpath)))))

  (defun my/lombok-jar-path (version)
    "Return path to Lombok jar in Maven repository."
    (expand-file-name
     (format "~/.m2/repository/org/projectlombok/lombok/%s/lombok-%s.jar" version version)))

  (defun my/ensure-lombok-downloaded (version)
    "Ensure Lombok VERSION is downloaded to Maven repository."
    (let ((jar-path (my/lombok-jar-path version)))
      (unless (file-exists-p jar-path)
        (message "Downloading Lombok %s..." version)
        (shell-command
         (format "mvn dependency:get -Dartifact=org.projectlombok:lombok:%s -q" version))
        (message "Lombok %s downloaded." version))
      (when (file-exists-p jar-path)
        jar-path)))

  (defun my/setup-lombok ()
    "Configure Lombok support based on project's Java version and dependencies.
Must be called BEFORE jdtls starts. Sets global lsp-java-vmargs."
    (when-let ((pom-dir (locate-dominating-file default-directory "pom.xml")))
      (let* ((project-root (expand-file-name pom-dir))
             (cached-jar (gethash project-root my/lombok-cache))
             (java-version (my/get-project-java-version)))
        (cond
         ;; Java 23+: Use javac mode - Lombok works as annotation processor
         ((and java-version (>= java-version 23))
          (unless (member "-Djava.jdt.ls.javac.enabled=on" lsp-java-vmargs)
            (setq lsp-java-vmargs
                  (append lsp-java-vmargs '("-Djava.jdt.ls.javac.enabled=on")))
            (message "Java %d: javac mode enabled (Lombok auto-discovered)" java-version)))

         ;; Java <23: Use -javaagent with Lombok jar
         (t
          (let ((lombok-jar (or cached-jar
                                (when-let ((version (or (my/get-lombok-version-from-maven)
                                                        (and (boundp 'lombok-version) lombok-version))))
                                  (my/ensure-lombok-downloaded version)))))
            (when lombok-jar
              (puthash project-root lombok-jar my/lombok-cache)
              (let ((agent-arg (concat "-javaagent:" lombok-jar)))
                ;; Remove any old lombok agents, add current one
                (setq lsp-java-vmargs
                      (append (seq-remove (lambda (arg) (string-match-p "-javaagent:.*lombok" arg))
                                          lsp-java-vmargs)
                              (list agent-arg)))
                (message "Lombok configured: %s" lombok-jar)))))))))

  ;; Advice lsp-java--ls-command to inject lombok BEFORE command is built
  (defun my/inject-lombok-into-vmargs (orig-fn)
    "Advice to inject Lombok agent into lsp-java-vmargs before command is built."
    (my/setup-lombok)
    (funcall orig-fn))

  (advice-add 'lsp-java--ls-command :around #'my/inject-lombok-into-vmargs))
  

(add-to-list 'safe-local-variable-values #'stringp)
(advice-add 'risky-local-variable-p :override #'ignore)


;; Email client seup
(use-package! mu4e
  ;; pull in org helpers
  ;;(require 'mu4e-org)
  :config
  (setq user-mail-address "alexander0derevianko@gmail.com"
      user-full-name  "Alexander Derevianko"
      ;; I have my mbsyncrc in a different folder on my system, to keep it separate from the
      ;; mbsyncrc available publicly in my dotfiles. You MUST edit the following line.
      ;; Be sure that the following command is: "mbsync -c ~/.config/mu4e/mbsyncrc -a"
      mu4e-get-mail-command "mbsync -c ~/.config/mu4e/mbsyncrc -a"
      mu4e-update-interval  300
      ;; mu4e-compose-signature
      ;;  (concat
      ;;    "Derek Taylor\n"
      ;;    "http://www.youtube.com/DistroTube\n")
      message-send-mail-function 'smtpmail-send-it
      starttls-use-gnutls t
      mu4e-root-maildir "~/Mail"
      ;; Make sure plain text mails flow correctly for recipients
      mu4e-compose-format-flowed t
      )

  (setq mu4e-contexts
        (list
        (make-mu4e-context
                :name "Personal"
                :match-func
                (lambda (msg)
                (when msg
                (string-prefix-p "/alex-derevianko" (mu4e-message-field msg :maildir))))
                :vars '((user-mail-address . "alexander0derevianko@gmail.com")
                        (user-full-name . "Alexander Derevianko")
                        (smtpmail-smtp-server . "smtp.gmail.com")
                        (smtpmail-smtp-service . 465)
                        (smtpmail-stream-type . ssl)
                        (mu4e-sent-folder . "/alex-derevianko/[Gmail]/Sent Mail")
                        (mu4e-drafts-folder . "/alex-derevianko/[Gmail]/Drafts")
                        (mu4e-trash-folder . "/alex-derevianko/[Gmail]/Trash")
                        (mu4e-refile-folder . "/alex-derevianko/[Gmail]/All Mail")
                        (mu4e-maildir-shortcuts . '(("/alex-derevianko/INBOX" . ?i)
                                                ("/alex-derevianko/[Gmail]/Sent Mail" . ?s)))
                        )))
        )
)
(use-package! org-mime
  :ensure t
  :config
  (setq org-mime-export-options '(:section-numbers nil
                                  :with-author nil
                                  :with-toc nil))
  (add-hook! 'message-send-hook 'org-mime-confirm-when-no-multipart))

;; Music emms
(use-package! emms
  :config
  (require 'emms-setup)
  (require 'emms-player-mpd)
  (emms-all)
  (setq emms-seek-seconds 5
        emms-player-list '(emms-player-mpd)
        emms-info-functions '(emms-info-mpd)))

(after! lsp-mode
  ;; Prevent Semgrep from receiving Java-specific commands it can't handle
  (lsp-disable-method-for-server "workspace/executeCommand" 'semgrep-ls)

  ;; Register nixd LSP client for Nix files
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection "nixd")
                    :major-modes '(nix-mode)
                    :priority 0
                    :server-id 'nixd))

  ;; Nix LSP configuration
  (setq lsp-nix-nil-formatter ["nixpkgs-fmt"]))

;; Enable LSP for nix-mode
(add-hook! 'nix-mode-hook #'lsp-deferred)

(after! claude-code-ide
  (use-package claude-code-ide
    :bind ("C-c C-'" . claude-code-ide-menu) ; Set your favorite keybinding
    :config
    (claude-code-ide-emacs-tools-setup))) ; Optionally enable Emacs MCP tools


(after! treemacs
    (setq treemacs-collapse-dirs 3)
  )
