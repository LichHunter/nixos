{ config, lib, pkgs, ... }:

{
  imports = [
    ./starship
    ./oxidise
    ./tmux
    ./fzf
  ];
}
