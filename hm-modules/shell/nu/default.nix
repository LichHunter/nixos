{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.dov.shell.nu;
in {
  options.dov.shell.nu = {
    enable = mkEnableOption "nushell config";
    shellAliases = mkOption {
      type = types.attrs;
      default = {};
    };
    carapace = {
      enable = mkEnableOption "carapace external completions";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs.nushell = {
        enable = true;

        settings = {
        };
      } // (lib.optionalAttrs (cfg.shellAliases != null) {
        shellAliases = cfg.shellAliases;
      });
    }

    (mkIf cfg.carapace.enable {
      home.packages = [ pkgs.carapace ];

      programs.nushell.extraConfig = ''
        let carapace_completer = {|spans: list<string>|
            # if the current command is an alias, get the aliased command
            let expanded_alias = (scope aliases | where name == $spans.0 | get value.0?.0?)
            # overwrite
            let spans = (if $expanded_alias != null  {
                $spans
                | skip 1
                | prepend ($expanded_alias | split row " " | take 1)
            } else { $spans })
            carapace $spans.0 nushell ...$spans
            | from json
        }

        $env.config.completions.external = {
            enable: true
            max_results: 100
            completer: $carapace_completer
        }
      '';
    })
  ]);
}
