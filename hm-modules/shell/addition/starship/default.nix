{ config, lib, pkgs, ... }:

with lib;

let cfg = config.dov.shell.addition.starship;
in {
  options.dov.shell.addition.starship.enable = mkEnableOption "starship configuration";

  config = mkIf cfg.enable {
    programs.starship = {
      enable = true;
      enableZshIntegration = config.dov.shell.zsh.enable;
      # TODO for now no bash - no integration
      #enableBashIntegration = config.dov.shell.bash.enable;

      settings = {
        nix_shell = {
          disabled = false;
          impure_msg = "";
          symbol = "";
          format = "[$symbol$state]($style) ";
        };
        shlvl = {
          disabled = false;
          symbol = "λ ";
        };
        haskell.symbol = " ";
        openstack.disabled = true;
        gcloud.disabled = true;
      };
    };
  };
}
