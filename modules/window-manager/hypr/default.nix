{ inputs, config, lib, pkgs, username, ... }:

with lib;

let
  colors = config.lib.stylix.colors;
  cfg = config.dov.window-manager.hypr;
  hm-cfg = config.home-manager.users.${username}.dov;
in {
  options.dov.window-manager.hypr.enable = mkEnableOption "hypr configuration";
  config = mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment = {
      systemPackages = with pkgs; [ wlr-randr wdisplays ];

      sessionVariables = {
        WLR_NO_HARWARE_CURSORS = "1";
        NIXOS_OZONE_WL = "1";
      };
    };

    hardware = {
      graphics.enable = true;
      nvidia.modesetting.enable = true;
    };

    # For screen sharing
    services.pipewire.enable = true;
    xdg = {
      portal = {
        enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-wlr
          xdg-desktop-portal-gtk
          xdg-desktop-portal-gnome
          xdg-desktop-portal
        ];
      };
    };

    home-manager.users.fujin.config = {
      home.packages = with pkgs; [
        swww
        mako
        pipewire
        wireplumber
        libnotify
        kitty
        jq # used in lock to get language
        wayland-protocols
        playerctl
        alsa-utils
        brightnessctl

        #hyprland extensions
        hyprlock
        hypridle
      ];

      wayland.windowManager.hyprland = {
        enable = true;
        xwayland.enable = true;
        package = inputs.hyprland.packages.${pkgs.system}.hyprland;
        plugins = [
          inputs.split-monitor-workspaces.packages.${pkgs.system}.split-monitor-workspaces
        ];

        settings = {
          monitor = ",highres,auto,1";
          source = "~/.config/hypr/colors";

          env = [
            "LIBVA_DRIVER_NAME,nvidia"
            "XDG_SESSION_TYPE,wayland"
            "WLR_NO_HARDWARE_CURSORS,1"
          ];

          #Autostart
          exec = [
            # Fix slow startup
            "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
            "dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          ];

          exec-once = [
            "mako"
            "polkit-kde-agent"
            "emacs --fg-daemon"
            "hypridle"
            "kanshi"
            "virsh net-start default"
            #"thunderbird"
            #"element-desktop"
            "keepassxc"
            "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          ] ++ lib.optionals hm-cfg.bar.waybar.enable [ "waybar" ];

          "$mainMod" = "SUPER";

          bind = [
            "$mainMod, G, fullscreen,"
            "$mainMod, t, togglegroup"
            "$mainMod, v, togglefloating"
            "$mainMod, s, togglesplit"

            #bind = $mainMod, RETURN, exec, kitty
            "$mainMod, RETURN, exec, alacritty"
            "$mainMod, o, exec, emacsclient -c"
            "SUPER_SHIFT, RETURN, exec, thunar"
            "SUPER_SHIFT, l, exec, hyprctl switchxkblayout at-translated-set-2-keyboard 0 && hyprlock"

            #bind = $mainMod, M, exit,
            "SUPER_SHIFT, q, killactive,"

            # Switch Keyboard Layouts
            "$mainMod, SPACE, exec, hyprctl switchxkblayout teclado-gamer-husky-blizzard next"

            '', Print, exec, grim -g "$(slurp)" - | wl-copy''
            ''
              SHIFT, Print, exec, IMG=~/Pictures/$(date +%Y-%m-%d_%H-%m-%s).png && grim -g "$(slurp)" $IMG''

            # Functional keybinds
            ",XF86AudioMicMute,exec,pamixer --default-source -t"
            ",XF86MonBrightnessDown,exec,brightnessctl s 20-"
            ",XF86MonBrightnessUp,exec,brightnessctl s 20+"
            ",XF86AudioMute,exec,amixer -q sset Master toggle"
            ",XF86AudioLowerVolume,exec,amixer -q sset Master 5%-"
            ",XF86AudioRaiseVolume,exec,amixer -q sset Master 5%+"
            ",XF86AudioPlay,exec,playerctl play-pause"
            ",XF86AudioPause,exec,playerctl play-pause"

            # to switch between windows in a floating workspace
            "SUPER,Tab,changegroupactive, f"
            "SUPER_SHIFT,Tab,changegroupactive, b"

            # Move focus with mainMod + arrow keys
            "$mainMod, h, movefocus, l"
            "$mainMod, l, movefocus, r"
            "$mainMod, k, movefocus, u"
            "$mainMod, j, movefocus, d"

            # Switch workspaces with mainMod + [0-9]
            "$mainMod, 1, split-workspace, 1"
            "$mainMod, 2, split-workspace, 2"
            "$mainMod, 3, split-workspace, 3"
            "$mainMod, 4, split-workspace, 4"
            "$mainMod, 5, split-workspace, 5"
            "$mainMod, 6, split-workspace, 6"
            "$mainMod, 7, split-workspace, 7"
            "$mainMod, 8, split-workspace, 8"
            "$mainMod, 9, split-workspace, 9"
            "$mainMod, 0, split-workspace, 10"

            # Move active window to a workspace with mainMod + SHIFT + [0-9]
            "$mainMod SHIFT, 1, split-movetoworkspace, 1"
            "$mainMod SHIFT, 2, split-movetoworkspace, 2"
            "$mainMod SHIFT, 3, split-movetoworkspace, 3"
            "$mainMod SHIFT, 4, split-movetoworkspace, 4"
            "$mainMod SHIFT, 5, split-movetoworkspace, 5"
            "$mainMod SHIFT, 6, split-movetoworkspace, 6"
            "$mainMod SHIFT, 7, split-movetoworkspace, 7"
            "$mainMod SHIFT, 8, split-movetoworkspace, 8"
            "$mainMod SHIFT, 9, split-movetoworkspace, 9"
            "$mainMod SHIFT, 0, split-movetoworkspace, 10"

            # Scroll through existing workspaces with mainMod + scroll
            "$mainMod, mouse_down, split-workspace, e+1"
            "$mainMod, mouse_up, split-workspace, e-1"
            "$mainMod,SPACE, exec, hyprctl switchxkblayout at-translated-set-2-keyboard next"

          ] ++ lib.optionals hm-cfg.launcher.wofi.enable
            [ "$mainMod, p, exec, wofi --show drun" ];

          bindm = [
            "$mainMod, mouse:272, movewindow"
            "$mainMod, mouse:273, resizewindow"
            "ALT, mouse:272, resizewindow"
          ];

          input = {
            kb_layout = "us,ru,ua";
            kb_options = "grp:win_space_toggle";

            follow_mouse = 1;

            touchpad = { natural_scroll = false; };

            sensitivity = 0;
          };

          general = {
            gaps_in = 5;
            gaps_out = 20;
            border_size = 2;
            "col.active_border" =
              lib.mkForce "rgba(33ccffee) rgba(00ff99ee) 45deg";
            "col.inactive_border" = lib.mkForce "rgba(595959aa)";

            layout = "dwindle";
          };

          decoration = {
            rounding = 10;

            shadow = {
              enabled = true;
              range = 4;
              render_power = 3;
            };
          };

          animations = {
            enabled = "yes";

            bezier = "ease,0.4,0.02,0.21,1";

            animation = [
              "windows, 1, 3.5, ease, slide"
              "windowsOut, 1, 3.5, ease, slide"
              "border, 1, 6, default"
              "fade, 1, 3, ease"
              "workspaces, 1, 3.5, ease"
            ];
          };

          dwindle = {
            pseudotile = "yes";
            preserve_split = "yes";
          };

          master = { new_status = "master"; };

          workspace = [
            #"0, monitor:DP-1"
            "8, monitor:e-DP-1"
            "9, monitor:e-DP-1"
            #"9, on-created-empty:[tiled] thunderbird"
          ];

          windowrulev2 = [
            "workspace 9, class:^(.*thunderbird.*)$"
            "group, class:^(.*thunderbird.*)$"
            "workspace 9, class:^(.*Element.*)$"
            "group, class:^(.*Element.*)$"
            "workspace 8, title:^(.*KeePassXC.*)$"
            "float, class:^(.*steam.*)$"
            "noinitialfocus,class:(jetbrains-)(.*),title:^win(.*), initialTitle:win.*, floating:1"
          ];
        };
      };

      home.file.".config/hypr/colors".text = ''
        $background = ${colors.base00}
        $foreground = ${colors.base05}

        $color0 = ${colors.base00}
        $color1 = ${colors.base01}
        $color2 = ${colors.base02}
        $color3 = ${colors.base03}
        $color4 = ${colors.base04}
        $color5 = ${colors.base05}
        $color6 = ${colors.base06}
        $color7 = ${colors.base07}
        $color8 = ${colors.base08}
        $color9 = ${colors.base09}
        $color10 = ${colors.base0A}
        $color11 = ${colors.base0B}
        $color12 = ${colors.base0C}
        $color13 = ${colors.base0D}
        $color14 = ${colors.base0E}
        $color15 = ${colors.base0F}
      '';

      xdg.configFile."hypr/hyprlock.conf".source = ./hyprlock.conf;
      xdg.configFile."hypr/hypridle.conf".source = ./hypridle.conf;
    };
  };
}
