{
  config,
  lib,
  pkgs,
  username,
  ...
}:

with lib;

let
  cfg = config.dov.virtualisation.incus;
in
{
  options.dov.virtualisation.incus = {
    enable = mkEnableOption "incus config";
  };

  config = mkIf cfg.enable {
    networking.nftables.enable = true;
    networking.firewall.interfaces.incusbr0.allowedTCPPorts = [
      53
      67
    ];
    networking.firewall.interfaces.incusbr0.allowedUDPPorts = [
      53
      67
    ];

    virtualisation.incus = {
      enable = true;

      preseed = {
        storage_pools = [
          {
            name = "default";
            driver = "dir";
          }
        ];
        networks = [
          {
            name = "incusbr0";
            type = "bridge";
            config = {
              "ipv4.address" = "auto";
              "ipv4.nat" = "true";
            };
          }
        ];
        profiles = [
          {
            name = "default";
            devices = {
              eth0 = {
                name = "eth0";
                network = "incusbr0";
                type = "nic";
              };
              root = {
                path = "/";
                pool = "default";
                type = "disk";
              };
            };
          }
        ];
      };
    };

    users.users.${username}.extraGroups = [ "incus-admin" ];
  };
}
