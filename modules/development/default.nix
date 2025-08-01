{ config, lib, pkgs, ... }:

{
  imports = [
    ./nix-vscode-server
    ./emacs
  ];
}
