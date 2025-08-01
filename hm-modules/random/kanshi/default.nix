{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.kanshi;
in {
  options.dov.kanshi.enable = mkEnableOption "kanshi config";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ kanshi ];

    services.kanshi = {
      enable = true;
      settings = [
        {
          profile = {
            name = "default";
            outputs = [
              {
                criteria = "eDP-1";
              }
            ];
          };
        }
        {
          profile = {
            name = "home";
            outputs = [
              {
                criteria = "eDP-1";
                position = "480,1440";
              }
              {
                criteria = "LG Electronics LG ULTRAWIDE 201NTTQC5617";
                position = "0,0";
                mode = "3440x1440";
              }
            ];
          };
        }
        {
          profile = {
            name = "reserve-home";
            outputs = [
              {
                criteria = "eDP-1";
                position = "480,1440";
              }
              {
                criteria = "DP-5";
                position = "0,0";
                mode = "3440x1440";
              }
            ];
          };
        }
      ];
    };
  };
}
