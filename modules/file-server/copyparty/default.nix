{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.file-server.copyparty;
in {
  options.dov.file-server.copyparty = { enable = mkEnableOption "copyparty config"; };

  config = mkIf cfg.enable {
    # # add the copyparty overlay to expose the package to the module
    # nixpkgs.overlays = [ copyparty.overlays.default ];
    # # (optional) install the package globally
    # environment.systemPackages = [ pkgs.copyparty ];
    # # configure the copyparty module
    # services.copyparty.enable = cfg.enable;
  };

}
