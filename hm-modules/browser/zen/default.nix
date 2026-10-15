{ inputs, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.browser.zen;
in {
  options.dov.browser.zen.enable = mkEnableOption "zen config";

  config = mkIf cfg.enable {
    home.packages = [
      inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".default
    ];
  };
}
