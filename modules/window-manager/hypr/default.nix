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
      # Launch Hyprland via UWSM (Universal Wayland Session Manager). This
      # automatically enables programs.uwsm and manages the systemd
      # graphical-session / wayland-session@Hyprland targets and environment.
      withUWSM = true;
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
        awww
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

      # The Hyprland config below is generated as native Lua (Hyprland >= 0.55).
      # Stylix's hyprland target emits hyprlang-style `settings` (flat dotted
      # keys like "col.active_border") which do not map cleanly onto the Lua
      # `hl.config{}` table API, and the previous config already force-overrode
      # stylix's borders anyway. We therefore disable the stylix hyprland target
      # and set the colors we care about explicitly in the Lua config.
      stylix.targets.hyprland.enable = lib.mkForce false;

      wayland.windowManager.hyprland = {
        enable = true;
        xwayland.enable = true;
        package = null;
        portalPackage = null;
        configType = "lua";

        # Required when launching Hyprland through UWSM: UWSM owns the systemd
        # graphical-session target, so home-manager must not create its own.
        systemd.enable = false;

        # split-monitor-workspaces is a Lua package (Hyprland >= 0.55), not a
        # C++ plugin: it's require()d in extraConfig, not loaded here.
        plugins = [ ];

        # Whole config written as native Lua. We use `extraConfig` (raw Lua)
        # rather than the `settings` attrset because Lua-mode binds need
        # `hl.dsp.*` dispatcher expressions, a `mainMod` local and a loop for
        # the workspace binds - none of which the attrset form expresses
        # cleanly ($variables render to invalid `hl.$mainMod(...)`).
        extraConfig = ''
          -- Migrated from hyprlang to Lua. See https://wiki.hypr.land/Configuring/Start/
          local mainMod = "SUPER"

          -- split-monitor-workspaces (Lua package). Use the absolute Nix store
          -- path: Hyprland's cwd is not the config dir, so the relative ./?.lua
          -- trick from upstream's README does not resolve under UWSM.
          package.path = package.path .. ";${inputs.split-monitor-workspaces}/lua/?.lua"
          local smw = require("split-monitor-workspaces")
          smw.setup({
            workspace_count = 10,
            keep_focused = true,
            enable_notifications = false,
            -- Don't pre-create empty workspaces: keeps the waybar workspaces
            -- module showing only workspaces that actually have windows (plus
            -- the currently focused one).
            enable_persistent_workspaces = false,
            enable_wrapping = true,
          })

          -- Monitors (was: monitor = ",preferred,auto,1")
          hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

          -- Environment
          hl.env("LIBVA_DRIVER_NAME", "nvidia")
          hl.env("XDG_SESSION_TYPE", "wayland")
          hl.env("WLR_NO_HARDWARE_CURSORS", "1")

          -- Config variables
          hl.config({
            general = {
              gaps_in = 5,
              gaps_out = 20,
              border_size = 2,
              col = {
                -- gradient active border (rgba(33ccffee) rgba(00ff99ee) 45deg)
                active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
                inactive_border = "rgba(595959aa)",
              },
              layout = "dwindle",
            },
            decoration = {
              rounding = 10,
              shadow = { enabled = true, range = 4, render_power = 3 },
            },
            input = {
              kb_layout = "us,ru,ua",
              kb_options = "grp:win_space_toggle",
              follow_mouse = 1,
              touchpad = { natural_scroll = false },
              sensitivity = 0,
            },
            animations = { enabled = true },
            dwindle = { preserve_split = true },
            master = { new_status = "master" },
          })

          -- Animation curves (was: bezier = ease,0.4,0.02,0.21,1)
          hl.curve("ease", { type = "bezier", points = { { 0.4, 0.02 }, { 0.21, 1 } } })

          -- Animations (was: NAME, ONOFF, SPEED, CURVE, [STYLE])
          hl.animation({ leaf = "windows",    enabled = true, speed = 3.5, bezier = "ease", style = "slide" })
          hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.5, bezier = "ease", style = "slide" })
          hl.animation({ leaf = "border",     enabled = true, speed = 6,   bezier = "ease" })
          hl.animation({ leaf = "fade",       enabled = true, speed = 3,   bezier = "ease" })
          hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "ease" })

          -- Keybinds
          hl.bind(mainMod .. " + G", hl.dsp.window.fullscreen())
          hl.bind(mainMod .. " + t", hl.dsp.group.toggle())
          hl.bind(mainMod .. " + v", hl.dsp.window.float({ action = "toggle" }))

          hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("alacritty"))
          hl.bind(mainMod .. " + o", hl.dsp.exec_cmd("emacsclient -c"))
          hl.bind("SUPER + SHIFT + RETURN", hl.dsp.exec_cmd("thunar"))
          hl.bind("SUPER + SHIFT + l", hl.dsp.exec_cmd("hyprctl switchxkblayout at-translated-set-2-keyboard 0 && hyprlock"))
          hl.bind("SUPER + SHIFT + q", hl.dsp.window.close())

          -- Switch keyboard layouts
          hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("hyprctl switchxkblayout teclado-gamer-husky-blizzard next"))

          -- Screenshots
          hl.bind("Print", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))
          hl.bind("SHIFT + Print", hl.dsp.exec_cmd([[IMG=~/Pictures/$(date +%Y-%m-%d_%H-%m-%s).png && grim -g "$(slurp)" $IMG]]))

          -- Functional / media keys
          hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pamixer --default-source -t"))
          hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 20-"))
          hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 20+"))
          hl.bind("XF86AudioMute", hl.dsp.exec_cmd("amixer -q sset Master toggle"))
          hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("amixer -q sset Master 5%-"))
          hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("amixer -q sset Master 5%+"))
          hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
          hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"))

          -- Switch between windows in a floating workspace (changegroupactive)
          hl.bind("SUPER + Tab", hl.dsp.group.next())
          hl.bind("SUPER + SHIFT + Tab", hl.dsp.group.prev())

          -- Move focus
          hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
          hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
          hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
          hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))

          -- Workspaces 1-10 (per-monitor): key 0 -> workspace 10
          for i = 1, smw.get_amount_of_workspaces() do
            local key = tostring(i)
            if key == "10" then key = "0" end
            hl.bind(mainMod .. " + " .. key, smw.workspace(tostring(i)))
            hl.bind(mainMod .. " + SHIFT + " .. key, smw.move_to_workspace_silent(tostring(i)))
          end

          -- Scroll through workspaces with mainMod + scroll
          hl.bind(mainMod .. " + mouse_down", smw.cycle_workspaces("next"))
          hl.bind(mainMod .. " + mouse_up", smw.cycle_workspaces("prev"))

          -- NOTE: pre-existing duplicate SUPER+SPACE bind (last one wins,
          -- identical to the original hyprlang config).
          hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("hyprctl switchxkblayout at-translated-set-2-keyboard next"))
        ''
        + lib.optionalString hm-cfg.launcher.wofi.enable ''
          hl.bind(mainMod .. " + p", hl.dsp.exec_cmd("wofi --show drun"))
        ''
        + ''

          -- Mouse binds (was: bindm)
          hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
          hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
          hl.bind("ALT + mouse:272", hl.dsp.window.resize(), { mouse = true })

          -- Workspace rules
          hl.workspace_rule({ workspace = "8", monitor = "eDP-1" })
          hl.workspace_rule({ workspace = "9", monitor = "eDP-1" })

          -- Window rules
          hl.window_rule({ match = { title = "^(.*KeePassXC.*)$" }, workspace = "8" })

          -- Autostart (was: exec-once). UWSM imports the session environment,
          -- so the old systemctl/dbus import-environment lines are dropped.
          hl.on("hyprland.start", function()
            hl.exec_cmd("polkit-kde-agent")
            hl.exec_cmd("emacs --fg-daemon")
            hl.exec_cmd("hypridle")
            hl.exec_cmd("kanshi")
            hl.exec_cmd("virsh net-start default")
            hl.exec_cmd("keepassxc")
        ''
        + lib.optionalString hm-cfg.bar.waybar.enable ''
            hl.exec_cmd("waybar")
            hl.exec_cmd("mako")
        ''
        + ''
          end)
        '';
      };

      # Stylix base16 palette exported as hyprlang variables. No longer sourced
      # from the main Lua config (Lua has no `source`); kept for reference and
      # for any hyprlang consumer that wants to source it.
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
