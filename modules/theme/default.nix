{ config, lib, pkgs, username, ... }:

with lib;

let
  # Access HM theme config
  hmCfg = config.home-manager.users.${username}.dov.dynamic-theme;
  
  allThemes = hmCfg.themes;

  # Generate all theme-variant combinations
  themeVariants = concatMapAttrs (name: theme: {
    "${name}-dark" = { scheme = theme.dark; polarity = "dark"; };
    "${name}-light" = { scheme = theme.light; polarity = "light"; };
  }) allThemes;

  # Base is gruvbox-dark, everything else is a specialisation
  baseVariant = "gruvbox-dark";
  specialisationVariants = filterAttrs (name: _: name != baseVariant) themeVariants;

  availableVariants = concatStringsSep " " (attrNames themeVariants);

  theme-switch = pkgs.writeShellScriptBin "theme-switch" ''
    case "$1" in
      ${baseVariant})
        echo "Switching to ${baseVariant}..."
        sudo nixos-rebuild switch --flake ~/nixos#${username}
        ;;
      ${concatStringsSep "\n      " (map (name: ''
      ${name})
        echo "Switching to ${name}..."
        sudo nixos-rebuild switch --flake ~/nixos#${username} --specialisation ${name}
        ;;'') (attrNames specialisationVariants))}
      *)
        echo "Usage: theme-switch <variant>"
        echo "Available: ${availableVariants}"
        exit 1
        ;;
    esac
  '';

in {
  options.dov.dynamic-theme.enable = mkEnableOption "NixOS dynamic theme specialisations";

  config = mkIf (config.dov.dynamic-theme.enable && hmCfg.enable) {
    # Add theme-switch script system-wide
    environment.systemPackages = [ theme-switch ];

    # Base theme: gruvbox-dark
    stylix = {
      base16Scheme = mkDefault themeVariants.${baseVariant}.scheme;
      polarity = mkDefault themeVariants.${baseVariant}.polarity;
    };

    # Generate NixOS specialisations for all other variants
    specialisation = mapAttrs (name: variant: {
      configuration = {
        stylix = {
          base16Scheme = mkForce variant.scheme;
          polarity = mkForce variant.polarity;
        };
      };
    }) specialisationVariants;
  };
}
