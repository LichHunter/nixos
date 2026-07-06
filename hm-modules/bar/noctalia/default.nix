{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  cfg = config.dov.bar.noctalia;
  c = config.lib.stylix.colors.withHashtag;

  # Build a noctalia palette from the active stylix base16 scheme.
  # Both dark/light keys carry the same values so the palette works
  # regardless of which theme.mode noctalia picks.
  mkPalette = variant: {
    mPrimary = c.base0D;
    mOnPrimary = c.base00;
    mSecondary = c.base0E;
    mOnSecondary = c.base00;
    mTertiary = c.base0C;
    mOnTertiary = c.base00;
    mError = c.base08;
    mOnError = c.base00;
    mSurface = if variant == "dark" then c.base00 else c.base07;
    mOnSurface = if variant == "dark" then c.base05 else c.base01;
    mSurfaceVariant = if variant == "dark" then c.base01 else c.base06;
    mOnSurfaceVariant = if variant == "dark" then c.base04 else c.base02;
    mHover = if variant == "dark" then mkForce c.base02 else mkForce c.base06;
    mOnHover = if variant == "dark" then mkForce c.base06 else mkForce c.base01;
    mOutline = c.base03;
    mShadow = c.base00;
    terminal = {
      background = if variant == "dark" then c.base00 else c.base07;
      foreground = if variant == "dark" then c.base05 else c.base01;
      cursor = if variant == "dark" then c.base05 else c.base01;
      cursorText = if variant == "dark" then c.base00 else c.base07;
      selectionBg = c.base02;
      selectionFg = if variant == "dark" then c.base05 else c.base01;
      normal = {
        black = c.base00;
        red = c.base08;
        green = c.base0B;
        yellow = c.base0A;
        blue = c.base0D;
        magenta = c.base0E;
        cyan = c.base0C;
        white = c.base05;
      };
      bright = {
        black = c.base03;
        red = c.base08;
        green = c.base0B;
        yellow = c.base0A;
        blue = c.base0D;
        magenta = c.base0E;
        cyan = c.base0C;
        white = c.base07;
      };
    };
  };

  themeMode = if config.stylix.polarity == "dark" then "dark" else "light";
in
{
  options.dov.bar.noctalia.enable = mkEnableOption "noctalia bar";

  config = mkIf cfg.enable {
    programs.noctalia = {
      enable = true;
      package = inputs.noctalia.packages.${pkgs.system}.default;
      systemd.enable = true;

      customPalettes.stylix = {
        dark = mkPalette "dark";
        light = mkPalette "light";
      };

      settings = {
        theme = {
          mode = themeMode;
          source = "custom";
          custom_palette = "stylix";
        };

        location.address = "Marseille, France";

        bar.main = {
          position = "top";
          thickness = 34;
          radius = 12;
          margin_h = 0;
          margin_v = 6;
          padding = 14;
          widget_spacing = 6;
          capsule = true;
          capsule_fill = "surface_variant";
          capsule_radius = 20.0;
          reserve_space = true;

          start = [ "workspaces" "media" "active_window" ];
          center = [ "clock" ];
          end = [ "tray" "caffeine" "keyboard_layout" "cpu" "ram" "brightness" "volume" "mic" "network" "battery" "session" ];
        };

        widget = {
          clock = {
            format = "{:%H:%M}";
            tooltip_format = "{:%A, %B %d, %Y}";
          };

          workspaces.display = "id";

          # Named sysmon instances — type field overrides the widget id
          cpu = {
            type = "sysmon";
            stat = "cpu_usage";
          };

          ram = {
            type = "sysmon";
            stat = "memory_usage";
          };

          # Microphone — named volume widget with input device
          mic = {
            type = "volume";
            device = "input";
          };

          battery.warning_threshold = 30;

          keyboard_layout = {
            display = "short";
            hide_when_single_layout = true;
          };
        };
      };
    };
  };
}
