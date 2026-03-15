{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  # pre generated wrapper stuff
  baseZshenvP1 = /* zsh */ ''
    # zsh-wrapped zshenv: DO NOT EDIT -- this file has been generated automatically.
    # This file is read for all shells.

    # Ensure this is only run once per shell
    if [[ -v __WRAPPED_ZSHENV_SOURCED ]]; then return; fi
    __WRAPPED_ZSHENV_SOURCED=1

    ${lib.optionalString (config.homeManagerProfileDir != null) ''
      if [[ -f ${config.homeManagerProfileDir}/etc/profile.d/hm-session-vars.sh ]]; then
        . ${config.homeManagerProfileDir}/etc/profile.d/hm-session-vars.sh
      fi
    ''}

    # Cover some of the work done by zsh NixOS program if it is not installed
    if [[ ! (-v __ETC_ZSHENV_SOURCED) ]]
    then
      HELPDIR="${pkgs.zsh}/share/zsh/$ZSH_VERSION/help"

      # Tell zsh how to find installed completions.
      for p in ''${(z)NIX_PROFILES}; do
          fpath=($p/share/zsh/site-functions $p/share/zsh/$ZSH_VERSION/functions $p/share/zsh/vendor-completions $fpath)
      done
    fi
  '';
  # post generated wrapper stuff
  baseZshenvP2 = /* zsh */ ''

    # Get zshenv from wrapped options if they exist
    # zdotdir files must be sourced first to maintain documented override rules
    ${lib.optionalString (config.zdotdir != null) /* zsh */ ''
      if [[ -f "${config.zdotdir}/.zshenv" ]]
      then
        source "${config.zdotdir}/.zshenv"
      fi
    ''}
    ${lib.optionalString (config.zshenv.path or null != null) /* zsh */ ''
      if [[ -f ${lib.escapeShellArg config.zshenv.path} ]]
      then
        source ${lib.escapeShellArg config.zshenv.path}
      fi
    ''}
  '';

  split = wlib.makeWrapper.splitDal (wlib.makeWrapper.aggregateSingleOptionSet { inherit config; });

  # generate the non-arg wrapper script items for zshenv so that nixpkgs doesn't remove our stuff.
  wrapcmd = partial: "echo ${lib.escapeShellArg partial} >> \"$2\"";
  wrapperBuild = lib.pipe split.other [
    (wlib.dag.unwrapSort "makeWrapper")
    (builtins.concatMap (
      v:
      let
        esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
      in
      if v.type or null == "unsetVar" then
        [ (wrapcmd "unset ${esc-fn v.data}") ]
      else if v.type or null == "env" then
        [ (wrapcmd "wrapperSetEnv ${esc-fn v.attr-name} ${esc-fn v.data}") ]
      else if v.type or null == "envDefault" then
        [ (wrapcmd "wrapperSetEnvDefault ${esc-fn v.attr-name} ${esc-fn v.data}") ]
      else if v.type or null == "prefixVar" then
        [ (wrapcmd "wrapperPrefixEnv ${lib.concatMapStringsSep " " esc-fn v.data}") ]
      else if v.type or null == "suffixVar" then
        [ (wrapcmd "wrapperSuffixEnv ${lib.concatMapStringsSep " " esc-fn v.data}") ]
      else if v.type or null == "prefixContent" then
        let
          env = builtins.elemAt v.data 0;
          sep = builtins.elemAt v.data 1;
          val = builtins.elemAt v.data 2;
          cmd = "wrapperPrefixEnv ${esc-fn env} ${esc-fn sep} ";
        in
        [ ''echo ${lib.escapeShellArg cmd}"$(cat ${esc-fn val})" >> "$2"'' ]
      else if v.type or null == "suffixContent" then
        let
          env = builtins.elemAt v.data 0;
          sep = builtins.elemAt v.data 1;
          val = builtins.elemAt v.data 2;
          cmd = "wrapperSuffixEnv ${esc-fn env} ${esc-fn sep} ";
        in
        [ ''echo ${lib.escapeShellArg cmd}"$(cat ${esc-fn val})" >> "$2"'' ]
      else if v.type or null == "chdir" then
        [ (wrapcmd "cd ${esc-fn v.data}") ]
      else if v.type or null == "runShell" then
        [ (wrapcmd v.data) ]
      else
        [ ]
    ))
    (builtins.concatStringsSep "\n")
  ];
  # init and teardown to make the above commands work
  wrapperInit =
    let
      setvarfunc = /* zsh */ ''wrapperSetEnv() { export "$1=$2"; }'';
      setvardefaultfunc = /* zsh */ ''wrapperSetEnvDefault() { [ -z "''${(P)1+x}" ] && export "$1=$2"; }'';
      prefixvarfunc = /* zsh */ ''wrapperPrefixEnv() { export "$1=''${(P)1:+$3$2}''${(P)1:-$3}"; }'';
      suffixvarfunc = /* zsh */ ''wrapperSuffixEnv() { export "$1=''${(P)1:+''${(P)1}$2}$3"; }'';
    in
    builtins.concatStringsSep "\n" (
      lib.optional (config.env or { } != { }) setvarfunc
      ++ lib.optional (config.envDefault or { } != { }) setvardefaultfunc
      ++ lib.optional (config.prefixVar or [ ] != [ ] || config.prefixContent or [ ] != [ ]) prefixvarfunc
      ++ lib.optional (config.suffixVar or [ ] != [ ] || config.suffixContent or [ ] != [ ]) suffixvarfunc
    );
  wrapperTeardown =
    let
      args =
        lib.optional (config.env or { } != { }) "wrapperSetEnv"
        ++ lib.optional (config.envDefault or { } != { }) "wrapperSetEnvDefault"
        ++ lib.optional (
          config.prefixVar or [ ] != [ ] || config.prefixContent or [ ] != [ ]
        ) "wrapperPrefixEnv"
        ++ lib.optional (
          config.suffixVar or [ ] != [ ] || config.suffixContent or [ ] != [ ]
        ) "wrapperSuffixEnv";
    in
    lib.optionalString (args != [ ]) "unfunction ${builtins.concatStringsSep " " args}";
  # make the main bin/zsh wrapper binary with the arg wrapper items and our generated ZDOTDIR
  wrapperEntry =
    let
      argv0 =
        if builtins.isString (config.argv0 or null) then
          [
            "--argv0"
            (lib.escapeShellArg config.argv0)
          ]
        else if config.argv0type or null == "resolve" then
          [ "--resolve-argv0" ]
        else
          [ "--inherit-argv0" ];
      baseArgs = map lib.escapeShellArg [
        config.wrapperPaths.input
        config.wrapperPaths.placeholder
      ];
      cliArgs = lib.pipe split.args [
        (wlib.makeWrapper.fixArgs { sep = config.flagSeparator or null; })
        (
          { addFlag, appendFlag }:
          let
            mapArgs =
              name:
              lib.flip lib.pipe [
                (map (
                  v:
                  let
                    esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
                  in
                  if builtins.isList (v.data or null) then
                    map esc-fn v.data
                  else if v ? data && v.data or null != null then
                    esc-fn v.data
                  else
                    [ ]
                ))
                lib.flatten
                (builtins.concatMap (v: [
                  "--${name}"
                  v
                ]))
              ];
          in
          mapArgs "add-flag" addFlag ++ mapArgs "append-flag" appendFlag
        )
      ];
      zdotArg = [
        "--set"
        "ZDOTDIR"
        (lib.escapeShellArg config.generated_zdotdir)
      ];
      srcsetup = p: "source ${lib.escapeShellArg "${p}/nix-support/setup-hook"}";
    in
    ''
      (
        OLD_OPTS="$(set +o)"
        ${srcsetup pkgs.dieHook}
        ${srcsetup pkgs.makeBinaryWrapper}
        eval "$OLD_OPTS"
        makeWrapper ${builtins.concatStringsSep " " (baseArgs ++ argv0 ++ zdotArg ++ cliArgs)}
      )
    '';
in
{
  config.constructFiles.zshenv = {
    relPath = lib.mkOverride 0 "${config.zdotFilesDirname}/.zshenv";
    content = builtins.concatStringsSep "\n" [
      wrapperTeardown
      baseZshenvP2
      (config.zshenv.content or "")
    ];
    builder = ''
      mkdir -p "$(dirname "$2")"
      echo ${lib.escapeShellArg baseZshenvP1} > "$2"
      ${wrapcmd wrapperInit}
      ${wrapperBuild}
      cat "$1" >> "$2"
    '';
    output = lib.mkOverride 0 config.zdotFilesOutput;
  };
  config.buildCommand.makeWrapper =
    wrapperEntry + "\n" + wlib.makeWrapper.wrapVariants { inherit config pkgs; };
}
