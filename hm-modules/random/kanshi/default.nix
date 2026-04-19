{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.dov.kanshi;
in
{
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
                position = "0,1440";
                mode = "2560x1440@165Hz";
              }
              {
                criteria = "LG Electronics LG ULTRAWIDE 201NTTQC5617";
                position = "2560,1440";
                mode = "3440x1440@49.95Hz";
              }
              {
                criteria = "Lenovo Group Limited LEN G34w-10 URW07XK8";
                position = "2560,0";
                mode = "3440x1440@50Hz";
              }
            ];
          };
        }
        {
          profile = {
            name = "home2";
            outputs = [
              {
                criteria = "eDP-1";
                position = "3840,720";
              }
              {
                criteria = "Samsung Electric Company U32R59x H1AK500000";
                position = "0,0";
                mode = "3840x2160";
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
                mode = "3440x1440@50Hz";
              }
            ];
          };
        }
      ];
    };
  };
}
