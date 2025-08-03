{ config, lib, pkgs, ... }:

{
  imports = [
    ./zsh
    ./nu
    ./addition
  ];
}
