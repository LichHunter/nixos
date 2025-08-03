{ config, lib, pkgs, ... }:

{
  imports = [
    ./shell
    ./bar
    ./launcher
    ./random
    ./browser
    ./terminal
  ];
}
