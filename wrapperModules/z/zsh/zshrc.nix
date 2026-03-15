{
  config,
  lib,
  ...
}:
let
  zshAliases = builtins.concatStringsSep "\n" (
    lib.mapAttrsToList (k: v: "alias -- ${lib.escapeShellArg "${k}=${v}"}") (
      lib.filterAttrs (k: v: v != null) config.zshAliases
    )
  );
  baseZshrc = /* zsh */ ''
    # zsh-wrapped zshrc: DO NOT EDIT -- this file has been generated automatically.
    # This file is read for all shells.

    # Ensure this is only run once per shell
    if [[ -v __WRAPPED_ZSHRC_SOURCED ]]; then return; fi
    __WRAPPED_ZSHRC_SOURCED=1

    # zsh-wrapped defined aliases
    ${zshAliases}

    # Get zshrc from wrapped options if they exist
    # zdotdir files must be sourced first to maintain documented override rules
    ${lib.optionalString (config.zdotdir != null) /* zsh */ ''
      if [[ -f "${config.zdotdir}/.zshrc" ]]
      then
        source "${config.zdotdir}/.zshrc"
      fi
    ''}
    ${lib.optionalString (config.zshrc.path or null != null) /* zsh */ ''
      if [[ -f ${lib.escapeShellArg config.zshrc.path} ]]
      then
        source ${lib.escapeShellArg config.zshrc.path}
      fi
    ''}
  '';
in
{
  config.constructFiles.zshrc = {
    relPath = lib.mkOverride 0 "${config.zdotFilesDirname}/.zshrc";
    content = baseZshrc + "\n" + (config.zshrc.content or "");
    output = lib.mkOverride 0 config.zdotFilesOutput;
  };
}
