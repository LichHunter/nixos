{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.dov.development.vscode-server;
in {
  options.dov.development.vscode-server = {
    enable = mkEnableOption "vscode server config";
  };

  config = mkIf cfg.enable {
    services.vscode-server = {
      enable = true;
      enableFHS = true;
    };
  };

}
