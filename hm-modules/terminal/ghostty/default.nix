{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.terminal.ghostty;
in {
  options.dov.terminal.ghostty = {
    enable = mkEnableOption "ghostty config";
    shell = mkOption {
      type = types.str;
      default = "${pkgs.zsh}/bin/zsh";
    };
  };

  config = mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      installVimSyntax = true;
      enableZshIntegration = config.dov.shell.zsh.enable;
      settings = {
        command = "${cfg.shell}";
      };
    };
  };
}
