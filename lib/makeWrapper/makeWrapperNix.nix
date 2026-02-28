{
  config,
  wlib,
  lib,
  bash,
  ...
}:
let
  prefuncs =
    let
      setvarfunc = /* bash */ ''wrapperSetEnv() { export "$1=$2"; }'';
      setvardefaultfunc = /* bash */ ''wrapperSetEnvDefault() { [ -z "''${!1+x}" ] && export "$1=$2"; }'';
      prefixvarfunc = /* bash */ ''wrapperPrefixEnv() { export "$1=''${!1:+$3$2}''${!1:-$3}"; }'';
      suffixvarfunc = /* bash */ ''wrapperSuffixEnv() { export "$1=''${!1:+''${!1}$2}$3"; }'';
    in
    lib.optional (config.env or { } != { }) setvarfunc
    ++ lib.optional (config.envDefault or { } != { }) setvardefaultfunc
    ++ lib.optional (config.prefixVar or [ ] != [ ] || config.prefixContent or [ ] != [ ]) prefixvarfunc
    ++ lib.optional (
      config.suffixVar or [ ] != [ ] || config.suffixContent or [ ] != [ ]
    ) suffixvarfunc;

  outdir = "${placeholder "out"}/${config.binDir or "bin"}";
  outpath = lib.escapeShellArg "${outdir}/${config.binName}";
  wrapcmd = partial: "echo ${lib.escapeShellArg partial} >> ${outpath}";

  arg0 = if builtins.isString (config.argv0 or null) then config.argv0 else "\"$0\"";

  split = wlib.makeWrapper.splitDal (
    wlib.makeWrapper.aggregateSingleOptionSet {
      inherit config;
      sortResult = false;
    }
  );
  args = lib.pipe split.args [
    (wlib.makeWrapper.fixArgs { sep = config.flagSeparator or null; })
    (
      { addFlag, appendFlag }:
      let
        mapArgs = lib.flip lib.pipe [
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
          (builtins.concatStringsSep " ")
        ];
      in
      ''${mapArgs addFlag} "$@" ${mapArgs (wlib.dag.unwrapSort "appendFlag" appendFlag)}''
    )
  ];

  finalcmd = "${
    if !builtins.isString (config.exePath or null) || config.exePath == "" then
      "${config.package}"
    else
      "${config.package}/${config.exePath}"
  } ${args}";

  buildCommands = lib.pipe split.other [
    (
      dal:
      dal
      ++ lib.optional (lib.isFunction (config.argv0type or null)) {
        name = "NIX_RUN_MAIN_PACKAGE";
        data = config.argv0type finalcmd;
        type = "runShell";
      }
    )
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
        [ ''echo ${lib.escapeShellArg cmd}"$(cat ${esc-fn val})" >> ${outpath}'' ]
      else if v.type or null == "suffixContent" then
        let
          env = builtins.elemAt v.data 0;
          sep = builtins.elemAt v.data 1;
          val = builtins.elemAt v.data 2;
          cmd = "wrapperSuffixEnv ${esc-fn env} ${esc-fn sep} ";
        in
        [ ''echo ${lib.escapeShellArg cmd}"$(cat ${esc-fn val})" >> ${outpath}'' ]
      else if v.type or null == "chdir" then
        [ (wrapcmd "cd ${esc-fn v.data}") ]
      else if v.type or null == "runShell" then
        [ (wrapcmd v.data) ]
      else
        [ ]
    ))
    (builtins.concatStringsSep "\n")
  ];
in
if
  !builtins.isString (config.binName or null)
  || config.binName == ""
  || !(lib.isStringLike (config.package or null))
then
  ""
else
  ''
    mkdir -p ${lib.escapeShellArg outdir}
    echo ${lib.escapeShellArg "#!${bash}/bin/bash"} > ${outpath}
    ${wrapcmd (builtins.concatStringsSep "\n" prefuncs)}
    ${buildCommands}
    ${lib.optionalString (!lib.isFunction (config.argv0type or null)) (
      wrapcmd "exec -a ${arg0} ${finalcmd}"
    )}
    chmod +x ${outpath}
  ''
