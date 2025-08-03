{ config, lib, pkgs, ... }:

{
  imports = [
    ./kanshi
    ./eza
    ./direnv
  ];
}
