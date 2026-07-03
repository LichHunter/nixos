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

  # `variant:schemeFile` pairs so the wallpaper picker can read each variant's
  # base16 palette at runtime.
  variantSchemes = concatStringsSep " "
    (mapAttrsToList (variant: v: "${variant}:${v.scheme}") themeVariants);

  # variant:doomtheme pairs consumed by the theme-switch script's
  # best-effort Doom Emacs hook (see ./theme-switch.sh).
  doomThemeMap = concatStringsSep " "
    (mapAttrsToList (variant: theme: "${variant}:${theme}") cfg.doomThemes);

  # Stylix is only declared on hosts that import its Home Manager module
  # (e.g. `fujin`). Servers (susano, izanagi, amaterasu, ...) don't, so
  # `stylix` isn't declared there. We probe option *declarations* (not
  # config values) to avoid an evaluation cycle.
  hasStylix = options ? stylix;

  # --- Wallpaper handling (runtime-cloned repo + palette matching) ----------
  wallpapersEnabled = cfg.wallpaperRepo != null;
  wallpapersDir = "${config.home.homeDirectory}/Wallpapers";
  # hyprpaper's config points here; set-wallpaper rebinds this symlink, so we
  # never have to write hyprpaper config ourselves.
  wallpaperSymlink = "${config.xdg.stateHome}/theme/wallpaper-current";

  wallpaper-pick = pkgs.writeShellScriptBin "wallpaper-pick" ''
    SCRIPT_TAG="wallpaper-pick"
    ${builtins.readFile ./log.sh}
    wallpapersDir="${wallpapersDir}"
    wallpaperRepo="${cfg.wallpaperRepo or ""}"
    variantSchemes="${variantSchemes}"
    MAGICK="${getExe pkgs.imagemagick}"
    GIT="${getExe pkgs.git}"
    ${builtins.readFile ./wallpaper-pick.sh}
  '';

  wallpaper-set = pkgs.writeShellScriptBin "wallpaper-set" ''
    SCRIPT_TAG="wallpaper-set"
    ${builtins.readFile ./log.sh}
    wallpaperSymlink="${wallpaperSymlink}"
    ${builtins.readFile ./set-wallpaper.sh}
  '';

  # Applied once at login (after hyprpaper) to seed a base-variant wallpaper.
  wallpaper-init = pkgs.writeShellScript "wallpaper-init" ''
    wp="$(${getExe wallpaper-pick} ${baseVariant} 2>/dev/null)" || exit 0
    [ -n "$wp" ] && ${getExe wallpaper-set} "$wp" || true
  '';

  # Userspace theme switcher: activates a pre-built Home Manager
  # specialisation generation. No sudo, no OS rebuild — just runs the
  # specialisation's activation script in the base HM generation.
  #
  # The script logic lives in ./theme-switch.sh (plain shell, no Nix
  # escaping); we only inject the config-derived values it needs.
  theme-switch = pkgs.writeShellScriptBin "theme-switch" ''
    SCRIPT_TAG="theme-switch"
    ${builtins.readFile ./log.sh}
    baseVariant="${baseVariant}"
    availableVariants="${availableVariants}"
    doomThemes="${doomThemeMap}"
    wallpapersEnabled="${if wallpapersEnabled then "1" else "0"}"
    wallpaperPickBin="${if wallpapersEnabled then getExe wallpaper-pick else ""}"
    wallpaperSetBin="${if wallpapersEnabled then getExe wallpaper-set else ""}"
    ${builtins.readFile ./theme-switch.sh}
  '';
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

    wallpaperRepo = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://example.org/me/wallpapers.git";
      description = ''
        Git URL of a wallpaper repository. When set, theme-switch also picks
        a random wallpaper whose palette matches the current variant and
        applies it via hyprpaper. The repo is cloned to
        `~/Wallpapers` on first use (a one-time, runtime cost — it is NOT
        fetched at build time, so `nix build` stays fast).
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = [ theme-switch ]
        ++ optionals wallpapersEnabled [ wallpaper-pick wallpaper-set ];
    }

    # Only reference the `stylix` option where it is actually declared.
    # `mkIf false` is NOT enough: the module system still rejects a
    # definition (even a disabled one) for an option that does not exist,
    # which breaks every host that doesn't import stylix. `optionalAttrs`
    # (keyed on `options ?`, i.e. *declarations* — never a config value) is
    # the recursion-free way to gate structure on stylix presence.
    (optionalAttrs hasStylix {
      stylix = {
        enable = true;
        autoEnable = true;
        # Base scheme/polarity; overridable per specialisation below.
        base16Scheme = mkDefault themeVariants.${baseVariant}.scheme;
        polarity = mkDefault themeVariants.${baseVariant}.polarity;
        # When we manage hyprpaper's wallpaper ourselves, disable stylix's
        # hyprpaper target so the two don't fight over the wallpaper path.
        targets.hyprpaper.enable = mkForce (!wallpapersEnabled);
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
    })

    # Wallpaper handling. These options always exist structurally (HM ships
    # services.hyprpaper and a freeform systemd.user.services), so we gate
    # the *values* with mkIf/optionals rather than shaping structure — that
    # avoids the config-depends-on-config recursion that optionalAttrs on a
    # config value would cause.
    {
      services.hyprpaper.enable = wallpapersEnabled;
      services.hyprpaper.settings = mkIf wallpapersEnabled {
        splash = false;
        wallpaper = [{ monitor = ""; path = wallpaperSymlink; }];
      };

      systemd.user.services.wallpaper-init = mkIf wallpapersEnabled {
        Unit = {
          Description = "Pick and apply a wallpaper matching the base theme";
          After = [ "hyprpaper.service" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${wallpaper-init}";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    }
  ]);
}
