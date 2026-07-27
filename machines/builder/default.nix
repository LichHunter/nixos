# Minimal NixOS configuration for a disposable LXC builder on Proxmox VE.
#
# Built via the `nixos-lxc` flake output using nixos-generators with
# format = "proxmox-lxc". The resulting tarball is uploaded to PVE's
# /var/lib/vz/template/cache/ and cloned by pve-build each time a
# disposable builder is needed.
#
# Responsibilities of this image:
#   * Run nix with flakes as the `builder` user so nixos-rebuild
#     --build-host builder@<hostname> works against it.
#   * Be a competent builder: all cores, hardlink dedup, keep-derivations
#     and keep-outputs, keep-going on failure, idle CPU scheduling.
#   * Accept SSH from the operator (`builder` user + admin keys shared
#     across the rest of the homelab). Root SSH is disabled.
#   * Stay tiny — no bootloader, no kernel, no home-manager. The proxmox-lxc
#     format module from nixpkgs already sets boot.isContainer = true and
#     handles the LXC-specific bits.
{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;

  # Operator keys — same ones baked into every other machine in this flake.
  # Whoever runs pve-build must hold a matching private key. Add more
  # keys here as needed; the authorized_keys list mirrors this exactly.
  adminKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBcGhVpjmWEw1GEw0y/ysJPa2v3+u/Rt/iES/Se2huH2 alexander0derevianko@gmail.com"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIGXvmStLAC4f+D9/b3/eKl6lb8xLQOfDqwu3Piocrr7ZAAAABHNzaDo= yubikey@fujin"
  ];
in {
  nixpkgs = {
    hostPlatform = "x86_64-linux";
    config.allowUnfree = true;
  };

  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      flake-registry = "";
      nix-path = config.nix.nixPath;

      # Parallelism — use every core the container can see.
      cores = 0;            # 0 = use all visible cores per build job
      max-jobs = "auto";    # auto = one local build job per core

      # Store hygiene — hardlink identical files so the store stays compact
      # across many sequential builds.
      auto-optimise-store = true;

      # Cache reuse — keep derivation files and their outputs around even
      # when no current generation references them. Massively speeds up
      # repeated builds of the same flakes and lets you inspect what a
      # prior build actually pulled in.
      gc-keep-derivations = true;
      gc-keep-outputs = true;

      # Don't abort the whole build on the first failing derivation — let
      # nix continue so the caller sees every failure in one pass.
      keep-going = true;

      # `builder` drives builds via nixos-rebuild --build-host. Trust it so
      # `nix copy --to ssh://builder@<ct>` from the caller works without
      # extra configuration.
      trusted-users = [ "builder" ];
      allowed-users = [ "builder" ];

      # Keep the default cache so flake inputs and build outputs resolve
      # without having to build them from source.
      substituters = lib.mkForce [ "https://cache.nixos.org/" ];
      trusted-public-keys = lib.mkForce [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };
    channel.enable = false;

    # Be polite to other tenants on the PVE node when no builds are running.
    daemonCPUSchedPolicy = "idle";

    registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };

  # Networking: PVE creates the veth pair and attaches it to the bridge, but
  # because NixOS is not a recognised PVE ostype (no setup plugin exists),
  # PVE cannot write the guest-side network config. We configure eth0 DHCP
  # ourselves via systemd-networkd. The proxmox-lxc module already enables
  # networking.useNetworkd; this block provides the matching .network file.
  systemd.network = {
    enable = true;
    networks."10-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig.DHCP = "yes";
    };
  };

  time.timeZone = "Europe/Warsaw";
  i18n.defaultLocale = "en_US.UTF-8";

  # `builder` is the only SSH-reachable account on this disposable. It is a
  # normal user (no root login via SSH — see services.openssh.settings below)
  # but has passwordless sudo for the rare case a build needs it. Build
  # traffic itself goes through nix-daemon, which trusts `builder`.
  users.users.builder = {
    isNormalUser = true;
    description = "Disposable LXC builder";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = adminKeys;
  };

  security.sudo = {
    enable = true;
    extraRules = [{
      users = [ "builder" ];
      commands = [{
        command = "ALL";
        options = [ "NOPASSWD" ];
      }];
    }];
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    ripgrep
    jq
    git
    tmux
    htop
    ncdu
    file
    iproute2
    nix-output-monitor   # `nom build` for friendlier nix build output
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";   # only `builder` may log in
      PasswordAuthentication = false;
    };
  };

  # This is a disposable image; do NOT change.
  system.stateVersion = "25.05";
}
