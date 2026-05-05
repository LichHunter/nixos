{ config, lib, pkgs, ... }:

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
  };

  config = mkIf cfg.enable {
    # HM-level stylix config inherits from NixOS level
    # Specialisations are handled by NixOS module
    stylix = {
      enable = true;
      autoEnable = true;
    };
  };
}
