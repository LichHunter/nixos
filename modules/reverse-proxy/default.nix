{ config, lib, pkgs, ... }:

{
  imports = [
    ./nginx
    ./traefik
    ./caddy
  ];
}
