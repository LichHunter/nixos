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
    unstable-home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "unstable";
    };


    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };


    ###
    # Applications and other
    ###
    copyparty.url = "github:9001/copyparty";

    vscode-server.url = "github:nix-community/nixos-vscode-server";

    emacs-overlay.url = "github:nix-community/emacs-overlay/master";

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "unstable";
    };

    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "unstable";
    };

    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland";
      inputs.nixpkgs.follows = "unstable";
    };

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    split-monitor-workspaces = {
      url = "github:Duckonaut/split-monitor-workspaces";
      inputs.hyprland.follows = "hyprland";
    };

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
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

    upkgs = import inputs.unstable {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };

    mkComputer = configurationNix: extraModules: username: inputs.nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs pkgs nixos-hardware extraHomeModules username; };

      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager

        configurationNix
      ] ++ extraModules;
    };

    mkUnstableComputer = configurationNix: extraModules: username: inputs.unstable.lib.nixosSystem {
      specialArgs = { inherit inputs upkgs nixos-hardware extraHomeModules username; };

      modules = [
        disko.nixosModules.disko
        inputs.unstable-home-manager.nixosModules.home-manager

        configurationNix
      ] ++ extraModules;
    };
  in {
    nixosConfigurations = {
      ###
      # Proxmox Homelab Machine
      ###
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

          # Applications
          inputs.copyparty.nixosModules.default
          inputs.vscode-server.nixosModules.default

          ./machines/susano
          ./modules
        ];
      };

      ###
      # Proxmox Remote Dev Machine
      ###
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

      ###
      # Omen Laptop
      ###
      fujin-minimal = mkUnstableComputer
        ./machines/fujin/minimal
        [
          nixos-hardware.nixosModules.omen-15-en0002np
        ] # Extra modules
        "fujin";

      fujin = mkUnstableComputer
        ./machines/fujin/main
        [
          nixos-hardware.nixosModules.omen-15-en0002np
          sops-nix.nixosModules.sops

          # Applications
          inputs.copyparty.nixosModules.default
          inputs.vscode-server.nixosModules.default
          inputs.stylix.nixosModules.stylix
          inputs.nix-ld.nixosModules.nix-ld

          ./modules
        ] # Extra modules
        "fujin";
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

      izanami-iso = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        modules = [
          home-manager.nixosModules.home-manager

          ./iso/iso
        ];

        specialArgs = {
          inherit inputs;

          username = "izanami";
          extraHomeModules = [
            ./hm-modules
          ];
        };

        format = "iso";
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
