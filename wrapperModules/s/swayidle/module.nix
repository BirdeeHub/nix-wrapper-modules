{
  wlib,
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  timeoutModule = {
    options = {
      timeout = mkOption {
        type = types.ints.positive;
        description = "Timeout in seconds";
      };
      command = mkOption {
        type = wlib.types.stringable;
        description = "Command to run after timeout";
      };
      resumeCommand = mkOption {
        type = types.nullOr wlib.types.stringable;
        default = null;
        description = "Command to run on activity";
      };
    };
  };
in
{
  imports = [ wlib.modules.default ];

  options = {
    timeouts = mkOption {
      type = types.listOf (types.submodule timeoutModule);
      default = [ ];
      description = "List of idle timeout actions";
    };

    events = mkOption {
      type = types.submodule {
        options = {
          before-sleep = mkOption {
            type = types.nullOr wlib.types.stringable;
            default = null;
            description = ''
                Executes command before systemd puts the computer to
              	See {manpage}`swayidle(1)`
            '';
          };
          after-resume = mkOption {
            type = types.nullOr wlib.types.stringable;
            default = null;
            description = ''
              Executes command after logind signals that the computer resumed from sleep.
              See {manpage}`swayidle(1)`.
            '';
          };
          lock = mkOption {
            type = types.nullOr wlib.types.stringable;
            default = null;
            description = ''
              Executes command when logind signals that the session should be locked.
            '';
          };
          unlock = mkOption {
            type = types.nullOr wlib.types.stringable;
            default = null;
            description = ''
              Executes command when logind signals that the session should be unlocked
            '';
          };
        };
      };
      default = { };
      description = "Run command on occurrence of an event";
    };

    extraArgs = mkOption {
      type = types.listOf wlib.types.stringable;
      default = [ "-w" ];
      description = "Extra arguments to pass to swayidle";
    };
  };

  config = {
    package = lib.mkDefault pkgs.swayidle;

    # We transform the module options into the flat list swayidle expects
    addFlag =
      let
        mkTimeout =
          t:
          [
            "timeout"
            (toString t.timeout)
            t.command
          ]
          ++ lib.optionals (t.resumeCommand != null) [
            "resume"
            t.resumeCommand
          ];

        # Filter out null values from the events submodule
        activeEvents = lib.filterAttrs (_: v: v != null) config.events;

        # Map the set into [ "event" "command" "event" "command" ]
        eventArgs = lib.concatLists (
          lib.mapAttrsToList (name: value: [
            name
            value
          ]) activeEvents
        );
      in
      config.extraArgs ++ (lib.concatMap mkTimeout config.timeouts) ++ eventArgs;

    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
