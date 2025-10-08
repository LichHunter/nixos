{ config, lib, pkgs, username, ... }:

let
  aliases = {
    java23 = "export JAVA_HOME='/home/${username}/jdk/openjdk23' && mvn -v";
    java21 = "export JAVA_HOME='/home/${username}/jdk/openjdk21' && mvn -v";
    java17 = "export JAVA_HOME='/home/${username}/jdk/openjdk17' && mvn -v";
    java11 = "export JAVA_HOME='/home/${username}/jdk/openjdk11' && mvn -v";
  };
in {
  imports = [
    ./vscode
    ./jetbrains
  ];

  config = {
    home.packages = with pkgs; [
      maven
      nodejs_22
      jdk21
    ];

    home.file."jdk/openjdk11".source = pkgs.jdk11;
    home.file."jdk/openjdk17".source = pkgs.jdk17;
    home.file."jdk/openjdk21".source = pkgs.jdk21;
    home.file."jdk/openjdk23".source = pkgs.jdk23;
    home.file."nodejs/nodejs_22".source = pkgs.nodejs_22;
    home.file."python/python3".source = pkgs.python3;
    home.file."jdk/zulujdk22".source = pkgs.zulu22;

    dov.shell = {
      zsh = {
        shellAliases = aliases;
      };

      nu = {
        #shellAliases = aliases;
      };
    };
  };
}
