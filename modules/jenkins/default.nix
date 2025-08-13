{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.jenkins;
in {
  options.dov.jenkins.enable = mkEnableOption "jenkins config";

  config = mkIf cfg.enable {
    services.jenkins = {
      enable = cfg.enable;
      port = 8081;
    };

    networking.firewall = {
      enable = cfg.enable;
      allowedTCPPorts = [ 8081 ];  # HTTP and HTTPS
    };
  };
}
