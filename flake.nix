{
  description = "Susano NixOS Homelab";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    copyparty.url = "github:9001/copyparty";

    vscode-server.url = "github:nix-community/nixos-vscode-server";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    nixos-generators,
    disko,
    home-manager,
    sops-nix,
    ...
  } @ inputs: let
    inherit (self) outputs;
    extraHomeModules = [
      ./hm-modules
    ];

    upkgs = import inputs.unstable { system = "x86_64-linux"; config.allowUnfree = true; };
  in {
    nixosConfigurations = {
      susano-minimal = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs extraHomeModules; };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          ./machines/susano-minimal
        ];
      };

      susano = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs extraHomeModules; };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          inputs.copyparty.nixosModules.default

          ./machines/susano
          ./modules
        ];
      };

      izanagi-minimal =
        let
          username = "izanagi";
        in nixpkgs.lib.nixosSystem {
          specialArgs = {inherit inputs outputs extraHomeModules username;};
          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            ./machines/izanagi-minimal
          ];
        };
      izanagi =
        let
          username = "izanagi";
        in nixpkgs.lib.nixosSystem {
          specialArgs = {inherit inputs outputs extraHomeModules username;};
          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops

            # Applications
            inputs.copyparty.nixosModules.default
            inputs.vscode-server.nixosModules.default

            ./machines/izanagi
            ./modules
          ];
        };
    };

    packages.x86_64-linux = {
      izanami-proxmox = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        modules = [
          home-manager.nixosModules.home-manager

          ./iso/proxmox
        ];

        specialArgs = {
          inherit inputs;

          username = "izanami";
          extraHomeModules = [
            ./hm-modules
          ];
        };

        format = "proxmox";
      };
    };

    devShells = {
      "x86_64-linux" = {
        default = upkgs.mkShell {
          buildInputs = with upkgs; [

            # AI Coding agents
            gemini-cli
            opencode
            claude-code
          ];

          shellHook = ''
          '';
        };
      };
    };
  };
}
