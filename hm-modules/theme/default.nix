{ config, lib, pkgs, options, ... }:

with lib;

let
  cfg = config.dov.dynamic-theme;
  schemes = "${pkgs.base16-schemes}/share/themes";

  # Curated defaults — covers the popular schemes without blowing up
  # build memory. Users can add more via `dov.dynamic-theme.themes`.
  builtinThemes = {
    gruvbox = {
      dark = "${schemes}/gruvbox-dark-hard.yaml";
      light = "${schemes}/gruvbox-light-hard.yaml";
    };
    catppuccin = {
      dark = "${schemes}/catppuccin-mocha.yaml";
      light = "${schemes}/catppuccin-latte.yaml";
    };
    nord = {
      dark = "${schemes}/nord.yaml";
      light = "${schemes}/nord-light.yaml";
    };
    solarized = {
      dark = "${schemes}/solarized-dark.yaml";
      light = "${schemes}/solarized-light.yaml";
    };
    tokyo-night = {
      dark = "${schemes}/tokyo-night-dark.yaml";
      light = "${schemes}/tokyo-night-light.yaml";
    };
    rose-pine = {
      dark = "${schemes}/rose-pine.yaml";
      light = "${schemes}/rose-pine-dawn.yaml";
    };
    one = {
      dark = "${schemes}/onedark.yaml";
      light = "${schemes}/one-light.yaml";
    };
    material = {
      dark = "${schemes}/material-darker.yaml";
      light = "${schemes}/material-lighter.yaml";
    };
    google = {
      dark = "${schemes}/google-dark.yaml";
      light = "${schemes}/google-light.yaml";
    };
    github = {
      dark = "${schemes}/github-dark.yaml";
      light = "${schemes}/github.yaml";
    };
  };

  # Generate all theme-variant combinations from the configured themes.
  # Each theme produces a "-dark" and "-light" variant.
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
      description = ''
        Available themes with dark and light variants. Each entry
        generates two specialisations (`<name>-dark` and
        `<name>-light`). Add more here to extend the defaults.
      '';
    };

    doomThemes = mkOption {
      type = types.attrsOf types.str;
      # Auto-generate sane defaults from the configured themes, then
      # overlay specific overrides for schemes that ship a dedicated
      # doom-theme.
      default =
        let
          generated = concatMapAttrs (name: _: {
            "${name}-dark" = "doom-one";
            "${name}-light" = "doom-one-light";
          }) cfg.themes;
        in generated // {
          "gruvbox-dark" = "doom-gruvbox";
          "solarized-dark" = "doom-solarized-dark";
          "solarized-light" = "doom-solarized-light";
          "tokyo-night-dark" = "doom-tokyo-night";
          "nord-dark" = "doom-nordic";
          "material-dark" = "doom-material";
          "rose-pine-dark" = "doom-rose-pine";
          "catppuccin-dark" = "doom-catppuccin-mocha";
          "catppuccin-light" = "doom-catppuccin-latte";
        };
      description = ''
        Mapping from variant name (e.g. "gruvbox-dark") to the Doom
        Emacs theme symbol. Defaults are auto-generated from the
        configured themes (dark → doom-one, light → doom-one-light)
        with overrides for schemes that have a dedicated doom-theme.
        Only themes installed in Doom will load; others are silently
        skipped.
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

    # Nushell tab-completion: declares `theme-switch`'s argument signature
    # so nushell completes variant names natively (takes priority over
    # carapace's generic fallback). `extraConfig` is `types.lines`, so it
    # merges cleanly with the carapace completer from hm-modules/shell/nu.
    (mkIf config.programs.nushell.enable {
      programs.nushell.extraConfig = ''
        def "nu-complete theme-variants" [] {
            "${availableVariants}" | split row " "
        }

        extern theme-switch [
            variant: string@"nu-complete theme-variants"
        ]
      '';
    })
  ]);
}
