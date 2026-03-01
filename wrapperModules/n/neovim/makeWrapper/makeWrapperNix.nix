maybe_compile:
{
  config,
  wlib,
  lib,
  luajit,
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
    [
      setvardefaultfunc
      suffixvarfunc
    ]
    ++ lib.optional (config.prefixVar or [ ] != [ ] || config.prefixContent or [ ] != [ ]) prefixvarfunc
    ++ lib.optional (config.env or { } != { }) setvarfunc;

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

  luarc-path = "${placeholder "out"}/${config.binName}-rc.lua";
  finalcmd = "${
    if config.exePath == "" then "${config.package}" else "${config.package}/${config.exePath}"
  } --cmd ${lib.escapeShellArg "source${luarc-path}"} ${args}";

  luaEnv = (config.package.lua.withPackages or luajit.withPackages) config.settings.nvim_lua_env;
  NVIM_LUA_PATH = ((config.package.lua or luajit).pkgs.luaLib.genLuaPathAbsStr luaEnv);
  NVIM_LUA_CPATH = ((config.package.lua or luajit).pkgs.luaLib.genLuaCPathAbsStr luaEnv);

  manifest-path = lib.escapeShellArg "${placeholder "out"}/${config.binName}-rplugin.vim";

  buildCommands =
    isFinal:
    lib.pipe split.other [
      (
        dal:
        lib.optional isFinal {
          name = "NVIM_SYSTEM_RPLUGIN_MANIFEST";
          type = "envDefault";
          esc-fn = lib.escapeShellArg;
          attr-name = "NVIM_SYSTEM_RPLUGIN_MANIFEST";
          data = manifest-path;
        }
        ++ dal
        ++ [
          {
            name = "NIX_PROPAGATED_LUA_PATH";
            type = "UNPROCESSED";
            data =
              (wrapcmd "wrapperSuffixEnv LUA_PATH ';' ${lib.escapeShellArg NVIM_LUA_PATH}\n")
              + "echo \"wrapperSuffixEnv LUA_PATH ';' \${LUA_PATH@Q}\" >> ${outpath}";
          }
          {
            name = "NIX_PROPAGATED_LUA_CPATH";
            type = "UNPROCESSED";
            data =
              (wrapcmd "wrapperSuffixEnv LUA_CPATH ';' ${lib.escapeShellArg NVIM_LUA_CPATH}\n")
              + "echo \"wrapperSuffixEnv LUA_CPATH ';' \${LUA_CPATH@Q}\" >> ${outpath}";
          }
        ]
        ++ lib.optional isFinal {
          name = "NIX_GENERATED_VIMINIT";
          type = "envDefault";
          esc-fn = lib.escapeShellArg;
          attr-name = "VIMINIT";
          data = "lua require(${builtins.toJSON "${config.settings.info_plugin_name}.init_main"})";
        }
        ++ lib.optional (isFinal && lib.isFunction (config.argv0type or null)) {
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
        else if v.type or null == "UNPROCESSED" then
          [ v.data ]
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
  /* bash */ ''
    mkdir -p ${lib.escapeShellArg outdir}
    { [ -e "$manifestLuaPath" ] && cat "$manifestLuaPath" || echo "$manifestLua"; } > ${lib.escapeShellArg luarc-path}
    echo ${lib.escapeShellArg "#!${bash}/bin/bash"} > ${outpath}
    ${wrapcmd (builtins.concatStringsSep "\n" prefuncs)}
    ${buildCommands false}
    ${wrapcmd "exec -a ${arg0} ${finalcmd}"}
    chmod +x ${outpath}

    export NVIM_RPLUGIN_MANIFEST=${manifest-path}
    export HOME="$(mktemp -d)"
    if ! $out/bin/${config.binName} -i NONE -n -V1rplugins.log \
      +UpdateRemotePlugins +quit! > outfile 2>&1; then
      cat outfile
      echo -e "\nGenerating rplugin.vim failed!"
      exit 1
    fi
    { [ -e "$setupLuaPath" ] && cat "$setupLuaPath" || echo "$setupLua"; } ${maybe_compile}> ${lib.escapeShellArg luarc-path}
    echo ${lib.escapeShellArg "#!${bash}/bin/bash"} > ${outpath}
    ${wrapcmd (builtins.concatStringsSep "\n" prefuncs)}
    ${buildCommands true}
    ${lib.optionalString (!lib.isFunction config.argv0type) (wrapcmd "exec -a ${arg0} ${finalcmd}")}
    chmod +x ${outpath}
  ''
