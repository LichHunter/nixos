{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.bar.waybar;
  color = config.lib.stylix.colors;
  backgound-color = color.base01;
  icon-color = color.base0A;
in {
  options.dov.bar.waybar.enable = mkEnableOption "waybar option";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      wlogout
      pavucontrol # gui sound manager
    ];

    programs.waybar = {
      enable = true;
      settings = {
        mainBar = {
          include = [ "~/.config/waybar/config.json" ];

          layer = "top";
          position = "top";
          margin-top = 5;
          margin-bottom = 5;
          margin-left = 5;
          margin-right = 5;
          height = 15;

          modules-left = [
            # "custom/launcher"
            "hyprland/workspaces"
            "custom/media"
            "hyprland/window"
          ];

          modules-center = [
            "clock"
          ];

          modules-right = [
            "tray"
            "idle_inhibitor"
            "hyprland/language"
            "memory"
            "cpu"
            "backlight#value"
            "pulseaudio"
            "pulseaudio#microphone"
            "network"
            "battery"
            "custom/power"
          ];

          "clock" = {
            format = "{:%H:%M, %d, %B, %Y}  ";
            format-alt = "{%R, :%A, %d %B, %Y}  ";
            tooltip-format = "<tt><small>{calendar}</small></tt>";
            calendar = {
              mode = "year";
              mode-mon-col = 3;
              weeks-pos = "right";
              on-scroll = 1;
              on-click-right = "mode";
              format = {
                months = "<span color='#${icon-color}'><b>{}</b></span>";
                days = "<span color='#${icon-color}'><b>{}</b></span>";
                weeks = "<span color='#${icon-color}'><b>W{}</b></span>";
                weekdays = "<span color='#${icon-color}'><b>{}</b></span>";
                today = "<span color='#${icon-color}'><b><u>{}</u></b></span>";
              };
            };
            actions = {
              on-click-right = "mode";
              on-click-forward = "tz_up";
              on-click-backward = "tz_down";
              on-scroll-up = "shift_up";
              on-scroll-down = "shift_down";
            };
          };
        };
      };

      style = lib.mkForce ''
        @keyframes blink-warning {
        70% {
        color: white;
        }

        to {
        color: white;
        background-color: orange;
        }
        }

        @keyframes blink-critical {
        70% {
        color: white;
        }

        to {
        color: white;
        background-color: red;
        }
        }


        /* Reset all styles */
        * {
        border: none;
        border-radius: 0;
        min-height: 0;
        margin: 1px;
        padding: 0;
        color: #${icon-color};
        }


        /* The whole bar */
        window#waybar {
        background-color: rgba(0,0,0,0);
        font-family: Intel One Mono Nerd Font;
        font-size: 14px;
        }

        /* Every modules */
        #battery,
        #clock,
        #backlight,
        #cpu,
        #custom-keyboard-layout,
        #memory,
        #mode,
        #custom-weather,
        #network,
        #pulseaudio,
        #temperature,
        #tray,
        #idle_inhibitor,
        #window,
        #workspaces,
        #custom-media,
        #language,
        #custom-power,
        #custom-PBPbattery {
        padding:0.25rem 0.75rem;
        margin: 1px 6px;
        background-color: #${backgound-color};
        border-radius: 20px;
        }

        #clock {
        color: #${icon-color};
        }

        #custom-weather {
        color: #ff4499;
        }

        #battery {
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
        }

        #battery.warning {
        color: orange;
        }

        #battery.critical {
        color: red;
        }

        #battery.warning.discharging {
        animation-name: blink-warning;
        animation-duration: 3s;
        }

        #battery.critical.discharging {
        animation-name: blink-critical;
        animation-duration: 2s;
        }

        #cpu {
        color: #${icon-color};
        }

        #cpu.warning {
        color: orange;
        }

        #cpu.critical {
        color: red;
        }

        #memory {
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
        color: #${icon-color};
        }

        #memory.warning {
        color: orange;
        }

        #memory.critical {
        color: red;
        animation-name: blink-critical;
        animation-duration: 2s;
        padding-left:5px;
        padding-right:5px;
        }

        #mode {
        border-bottom: 3px transparent;
        color:#ff4499;
        margin-left: 5px;
        padding: 7px;
        }

        #network.disconnected {
        color: orange;
        }

        #pulseaudio {
        color: #${icon-color};
        border-left: 0px;
        border-right: 0px;
        margin-right: 0;
        border-radius: 20px 0 0 20px;
        }

        #pulseaudio.microphone {
        border-left: 0px;
        border-right: 0px;
        margin-left: 0;
        padding-left: 0;
        border-radius: 0 20px 20px 0;
        }

        #temperature.critical {
        color: red;
        }

        #window {
        font-weight: bold;
        color: #${icon-color};
        }

        #custom-media {
        color: #bb9af7;
        }

        #workspaces {
        font-size:16px;
        background-color: #${backgound-color};
        border-radius: 20px;
        }

        #workspaces button {
        border-bottom: 3px solid transparent;
        margin-bottom: 0px;
        color: #dfdfdf;
        }

        #workspaces button.active {
        border-bottom: 1px solid #${color.base0B};
        margin-bottom: 1px;
        padding-left:0;
        }

        #workspaces button.urgent {
        border-color: #c9545d;
        color: #c9545d;
        }

        #custom-power {
        font-size:18px;
        padding-right: 1rem;
        }

        #custom-launcher {
        font-size:15px;
        margin-left:15px;
        margin-right:10px;
        }

        #backlight.icon {
        padding-right:1px;
        font-size: 13px;
        }
      '';
    };
    home.file.".config/waybar/config.json".source = ./waybar4.json;
  };
}
