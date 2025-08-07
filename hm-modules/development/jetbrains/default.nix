{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.development.jetbrains;
in {
  options.dov.development.jetbrains = {
    toolbox.enable = mkEnableOption "toolbox config";
  };

  config = {
    home.packages = [] ++ optionals cfg.toolbox.enable [ pkgs.jetbrains-toolbox ];
  };

}
