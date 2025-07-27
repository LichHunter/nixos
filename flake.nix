{
  description = "Susano NixOS Homelab";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
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
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    disko,
    home-manager,
    sops-nix,
    ...
  } @ inputs: let
    inherit (self) outputs;
    extraHomeModules = [
      ./hm-modules
    ];
  in {
    nixosConfigurations = {
      susano-minimal = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs extraHomeModules; };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          ./minimal
        ];
      };

      susano = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs extraHomeModules; };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          inputs.copyparty.nixosModules.default

          ./main
          ./modules
        ];
      };
    };
  };
}
