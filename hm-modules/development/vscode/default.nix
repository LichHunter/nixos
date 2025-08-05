{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.development.vscode;
in {

  options.dov.development.vscode.enable = mkEnableOption "vscode config";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      vscode.fhs
    ];
  };
}
