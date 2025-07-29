{ config, lib, pkgs, ... }:

{
  imports = [
    ./authelia
    ./ldap
  ];
}
