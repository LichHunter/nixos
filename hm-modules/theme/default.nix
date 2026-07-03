{ config, lib, pkgs, options, ... }:

with lib;

let
  cfg = config.dov.dynamic-theme;
  schemes = "${pkgs.base16-schemes}/share/themes";

  # Single source of truth for builtin themes
  builtinThemes = {
    gruvbox = {
      dark = "${schemes}/gruvbox-dark-hard.yaml";
      light = "${schemes}/gruvbox-light-hard.yaml";
    };
    catppuccin = {
      dark = "${schemes}/catppuccin-mocha.yaml";
      light = "${schemes}/catppuccin-latte.yaml";
    };
  };

  # Generate all theme-variant combinations
  themeVariants = concatMapAttrs (name: theme: {
    "${name}-dark" = { scheme = theme.dark; polarity = "dark"; };
    "${name}-light" = { scheme = theme.light; polarity = "light"; };
  }) cfg.themes;

  # Base is gruvbox-dark, everything else is a specialisation
  baseVariant = "gruvbox-dark";
  specialisationVariants = filterAttrs (name: _: name != baseVariant) themeVariants;

  availableVariants = concatStringsSep " " (attrNames themeVariants);

  # variant:doomtheme pairs consumed by the theme-switch script's
  # best-effort Doom Emacs hook (see ./theme-switch.sh).
  doomThemeMap = concatStringsSep " "
    (mapAttrsToList (variant: theme: "${variant}:${theme}") cfg.doomThemes);

  # Userspace theme switcher: activates a pre-built Home Manager
  # specialisation generation. No sudo, no OS rebuild — just runs the
  # specialisation's activation script in the base HM generation.
  #
  # The script logic lives in ./theme-switch.sh (plain shell, no Nix
  # escaping); we only inject the config-derived values it needs.
  theme-switch = pkgs.writeShellScriptBin "theme-switch" ''
    baseVariant="${baseVariant}"
    availableVariants="${availableVariants}"
    doomThemes="${doomThemeMap}"
    ${builtins.readFile ./theme-switch.sh}
  '';

  # Stylix is only declared on hosts that import its Home Manager module
  # (e.g. `fujin`). Servers (susano, izanagi, amaterasu, ...) don't, so
  # `stylix` isn't declared there. We probe option *declarations* (not
  # config values) to avoid an evaluation cycle.
  hasStylix = options ? stylix;
in {
  options.dov.dynamic-theme = {
    enable = mkEnableOption "dynamic theme switching";

    themes = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          dark = mkOption {
            type = types.path;
            description = "Path to dark variant base16 scheme";
          };
          light = mkOption {
            type = types.path;
            description = "Path to light variant base16 scheme";
          };
        };
      });
      default = builtinThemes;
      description = "Available themes with dark and light variants";
    };

    doomThemes = mkOption {
      type = types.attrsOf types.str;
      default = {
        gruvbox-dark = "doom-gruvbox";
        gruvbox-light = "doom-one-light";
        catppuccin-dark = "doom-one";
        catppuccin-light = "doom-one-light";
      };
      description = ''
        Mapping from theme variant name (e.g. "gruvbox-dark") to the Doom
        Emacs theme symbol (e.g. "doom-gruvbox") that theme-switch will
        live-load via emacsclient when switching to that variant. Variants
        absent from this map are left unchanged in Emacs.

        Only themes actually installed in Doom will load; the defaults use
        themes bundled with doom-themes (so they work out of the box, though
        catppuccin variants fall back to generic dark/light). For accurate
        catppuccin colours, install the `catppuccin-theme` Emacs package and
        map the variants to `catppuccin-mocha` / `catppuccin-latte`.
      '';
    };
  };

  config = mkIf cfg.enable (
    {
      home.packages = [ theme-switch ];
    }
    # Only reference the `stylix` option where it is actually declared.
    # `mkIf false` is NOT enough: the module system still rejects a
    # definition (even a disabled one) for an option that does not exist,
    # which breaks every host that doesn't import stylix. `optionalAttrs`
    # removes the key structurally, so non-stylix hosts evaluate cleanly.
    // optionalAttrs hasStylix {
      stylix = {
        enable = true;
        autoEnable = true;
        # Base scheme/polarity; overridable per specialisation below.
        base16Scheme = mkDefault themeVariants.${baseVariant}.scheme;
        polarity = mkDefault themeVariants.${baseVariant}.polarity;
      };

      # Generate Home Manager specialisations for every non-base variant.
      # Each is pre-built into the nix store during the single rebuild and
      # activated userspace via `theme-switch` (no sudo, no OS rebuild).
      specialisation = mapAttrs (name: variant: {
        configuration = {
          stylix = {
            base16Scheme = mkForce variant.scheme;
            polarity = mkForce variant.polarity;
          };
        };
      }) specialisationVariants;
    }
  );
}
