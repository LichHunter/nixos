{ config, lib, pkgs, ... }:

{
  imports = [
    ./reverse-proxy
    ./virtualisation
  ];
}
