{ config, lib, pkgs, ... }:

{
  imports = [
    ./podman
    ./docker
  ];
}
