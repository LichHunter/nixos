{
  config,
  lib,
  pkgs,
  username,
  ...
}:
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "pve-build" ''
      export PATH="${
        lib.makeBinPath [
          pkgs.jq
          pkgs.openssh
        ]
      }:$PATH"
      ${builtins.readFile ./pve-build.sh}
    '')
  ];

  home-manager.users.${username} = {
    programs.nushell.extraConfig =
      lib.mkIf config.home-manager.users.${username}.programs.nushell.enable
        ''
          def "nu-complete pve-build-cmds" [] {
              [build test switch boot check-image deploy-image update-image start-builder build-on activate destroy-builder info]
          }

          def "nu-complete pve-build-activate" [] {
              [test switch boot]
          }

          extern pve-build [
              command?: string@"nu-complete pve-build-cmds"
              --machine: string
              --pve-host: string
              --pve-storage: string
              --rootfs-storage: string
              --bridge: string
              --vmid-start: int
              --vmid-floor: int
              --rootfs-gib: int
          --keep
          --local-build
          --show-trace
              --verbose
              --debug
              --help(-h)
          ]
        '';
  };
}
