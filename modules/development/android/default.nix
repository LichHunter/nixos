{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  cfg = config.dov.development.android;

  mtk-udev-rules = pkgs.writeTextFile {
    name = "mtk-udev-rules";
    destination = "/etc/udev/rules.d/60-mtk.rules";
    text = ''
      # MediaTek BROM (0003), Preloader VCOM (2000/2001), META (6000)
      SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0666", TAG+="uaccess"
      # Oppo/Realme fastboot + adb
      SUBSYSTEM=="usb", ATTR{idVendor}=="22d9", MODE="0666", TAG+="uaccess"

      # keep ModemManager's hands off the preloader port
      SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", ENV{ID_MM_DEVICE_IGNORE}="1"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="0e8d", ENV{ID_MM_DEVICE_IGNORE}="1"
    '';
  };
in
{
  options.dov.development.android = {
    enable = lib.mkEnableOption "Android and MediaTek flashing tools";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      android-tools
      mtkclient
      usbutils
    ];

    users.users.${username}.extraGroups = [ "dialout" ];

    services.udev.packages = [ mtk-udev-rules ];
  };
}
