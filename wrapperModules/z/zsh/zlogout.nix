{
  config,
  lib,
  ...
}:
let
  baseZlogout = /* zsh */ ''
    # zsh-wrapped zlogout: DO NOT EDIT -- this file has been generated automatically.
    # This file is read for all shells.

    # Ensure this is only run once per shell
    if [[ -v __WRAPPED_ZLOGOUT_SOURCED ]]; then return; fi
    __WRAPPED_ZLOGOUT_SOURCED=1

    # Get zlogout from wrapped options if they exist
    # zdotdir files must be sourced first to maintain documented override rules
    ${lib.optionalString (config.zdotdir != null) /* zsh */ ''
      if [[ -f "${config.zdotdir}/.zlogout" ]]
      then
        source "${config.zdotdir}/.zlogout"
      fi
    ''}
    ${lib.optionalString (config.zlogout.path or null != null) /* zsh */ ''
      if [[ -f ${lib.escapeShellArg config.zlogout.path} ]]
      then
        source ${lib.escapeShellArg config.zlogout.path}
      fi
    ''}
  '';
in
{
  config.constructFiles.zlogout = {
    relPath = lib.mkOverride 0 "${config.zdotFilesDirname}/.zlogout";
    content = baseZlogout + "\n" + (config.zlogout.content or "");
    output = lib.mkOverride 0 config.zdotFilesOutput;
  };
}
