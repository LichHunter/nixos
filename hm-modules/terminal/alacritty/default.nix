{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.terminal.alacritty;
in {
  options.dov.terminal.alacritty.enable = mkEnableOption "alacritty configuration";

  config = mkIf cfg.enable {
    programs = {
      alacritty = {
        enable = true;
      };
    };
  };
}
