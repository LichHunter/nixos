{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.shell.zsh;
in {
  options.dov.shell.zsh = {
    enable = mkEnableOption "zsh config";
    shellAliases = mkOption {
      type = types.attrs;
      default = {};
    };
  };

  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      history = {
        save = 10000;
      };

      initContent = ''
      '';

      plugins = [
        {
          # will source zsh-autosuggestions.plugin.zsh
          name = "zsh-autosuggestions";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-autosuggestions";
            rev = "v0.7.0";
            sha256 = "0z6i9wjjklb4lvr7zjhbphibsyx51psv50gm07mbb0kj9058j6kc";
          };
        }
        {
          # will source zsh-autosuggestions.plugin.zsh
          name = "zsh-syntax-highlighting";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-syntax-highlighting";
            rev = "0.7.0";
            sha256 = "eRTk0o35QbPB9kOIV0iDwd0j5P/yewFFISVS/iEfP2g=";
          };
        }
      ];
      oh-my-zsh = {
        enable = true;
        theme = "bira";
        plugins = [ "git" "sudo" ];
      };
    } // (lib.optionalAttrs (cfg.shellAliases != null) {
      shellAliases = cfg.shellAliases;
    });
  };
}
