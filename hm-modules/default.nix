{ config, lib, pkgs, ... }:

{
  imports = [
    ./shell
    ./window-manager
    ./bar
    ./launcher
    ./random
    ./browser
    ./terminal
  ];
}
