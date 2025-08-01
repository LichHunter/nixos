{ config, lib, pkgs, ... }:

with lib;

let cfg = config.dov.launcher.wofi;
in {
  options.dov.launcher.wofi.enable = mkEnableOption "wofi configuration";

  config = mkIf cfg.enable {

    home.packages = [ pkgs.wofi ];

  };

}
