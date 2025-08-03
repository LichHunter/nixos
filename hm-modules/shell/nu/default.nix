{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.shell.nu;
in {
  options.dov.shell.nu = {
    enable = mkEnableOption "nushell config";
    shellAliases = mkOption {
      type = types.attrs;
      default = {};
    };
  };

  config = mkIf cfg.enable {
    programs.nushell = {
      enable = true;

      settings = {
      };
    } // (lib.optionalAttrs (cfg.shellAliases != null) {
      shellAliases = cfg.shellAliases;
    });
  };
}
