{
  config,
  lib,
  ...
}:
let
  baseZlogin = /* zsh */ ''
    # zsh-wrapped zlogin: DO NOT EDIT -- this file has been generated automatically.
    # This file is read for all shells.

    # Ensure this is only run once per shell
    if [[ -v __WRAPPED_ZLOGIN_SOURCED ]]; then return; fi
    __WRAPPED_ZLOGIN_SOURCED=1

    # Get zlogin from wrapped options if they exist
    # zdotdir files must be sourced first to maintain documented override rules
    ${lib.optionalString (config.zdotdir != null) /* zsh */ ''
      if [[ -f "${config.zdotdir}/.zlogin" ]]
      then
        source "${config.zdotdir}/.zlogin"
      fi
    ''}
    ${lib.optionalString (config.zlogin.path or null != null) /* zsh */ ''
      if [[ -f ${lib.escapeShellArg config.zlogin.path} ]]
      then
        source ${lib.escapeShellArg config.zlogin.path}
      fi
    ''}
  '';
in
{
  config.constructFiles.zlogin = {
    relPath = lib.mkOverride 0 "${config.zdotFilesDirname}/.zlogin";
    content = baseZlogin + "\n" + (config.zlogin.content or "");
    output = lib.mkOverride 0 config.zdotFilesOutput;
  };
}
