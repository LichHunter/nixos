{ inputs, config, lib, pkgs, username, ... }:

with lib;

let
  cfg = config.dov.development.emacs;
in {

  options.dov.development.emacs = { enable = mkEnableOption "emacs config"; };

  config = mkIf cfg.enable {
    nixpkgs.overlays = [
      inputs.emacs-overlay.overlay
    ];

    users.users."${username}" = {

      packages = with pkgs; [
        ## Emacs itself
        binutils # native-comp needs 'as', provided by this
        # 28.2 + native-comp
        ((emacsPackagesFor emacs-unstable).emacsWithPackages (epkgs: [
          epkgs.vterm
          epkgs.treesit-grammars.with-all-grammars
          epkgs.mu4e
          epkgs.org-mime

        ]))

        ## Doom dependencies
        git
        (ripgrep.override {withPCRE2 = true;})
        gnutls              # for TLS connectivity

        ## Optional dependencies
        fd                  # faster projectile indexing
        imagemagick         # for image-dired
        pinentry-emacs   # in-emacs gnupg prompts
        zstd                # for undo-fu-session/undo-tree compression

        ## Module dependencies
        # :checkers spell
        (aspellWithDicts (ds: with ds; [ en en-computers en-science ]))
        # :tools editorconfig
        editorconfig-core-c # per-project style config
        # :tools lookup & :lang org +roam
        sqlite
        # :lang latex & :lang org (latex previews)
        texlive.combined.scheme-medium
        # :lang nix
        nixfmt-classic
        #nixd
        nil
        # :lang lisp
        sbcl
        # :lang sh
        shellcheck
        # :lang typescript
        #javascript-typescript-langserver # deprecated
        deno
        # :lang go
        # go
        # gopls
        # gotests
        # gomodifytags
        # gore
        # gotools
        # :lang ruby
        ruby
        rbenv
        rubocop

        isync # mu4e related
      ];

    };
  };

}
