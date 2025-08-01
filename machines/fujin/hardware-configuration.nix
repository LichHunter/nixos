{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    loader.grub = {
      enable = true;
      useOSProber = true;
    };

    initrd = {
      availableKernelModules =
        [ "nvme" "xhci_pci" "usb_storage" "sd_mod" "sdhci_pci" ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-amd" ];

    # allow perf as user | needed for intellij to run profiler
    kernel.sysctl."kernel.perf_event_paranoid" = 1;
    kernel.sysctl."kernel.kptr_restrict" = lib.mkForce 0;
  };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.nvidia.prime = {
    amdgpuBusId = lib.mkForce "PCI:7:0:0";
  };
}
