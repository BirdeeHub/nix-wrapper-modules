maybe_compile:
{
  config,
  wlib,
  lib,
  bash,
  luajit,
  ...
}:
let
  inherit (builtins) elemAt;
  generateArgsFromFlags = genArgs flaggenfunc;
  genArgs =
    f: default-sep: dag:
    wlib.dag.dagToDal (
      builtins.mapAttrs (
        n: v:
        let
          genArgs =
            sep: name: value:
            if lib.isList value then lib.concatMap (v: f true sep name v) value else f false sep name value;
        in
        v // { data = genArgs (if v.sep or null != null then v.sep else default-sep) n v.data; }
      ) dag
    );
  flaggenfunc =
    is_list: flagSeparator: name: value:
    if !is_list && (value == false || value == null) then
      [ ]
    else if !is_list && value == true then
      [
        name
      ]
    else if lib.trim flagSeparator == "" && flagSeparator != "" then
      [
        name
        (toString value)
      ]
    else
      [
        "${name}${flagSeparator}${toString value}"
      ];

  preFlagStr = builtins.concatStringsSep " " (
    wlib.dag.sortAndUnwrap {
      dag =
        lib.optionals (config.addFlag != [ ]) config.addFlag
        ++ lib.optionals (config.flags != { }) (
          generateArgsFromFlags (config.flagSeparator or " ") config.flags
        );
      mapIfOk =
        v:
        let
          esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
        in
        if builtins.isList v.data then builtins.concatStringsSep " " (map esc-fn v.data) else esc-fn v.data;
    }
  );
  postFlagStr = builtins.concatStringsSep " " (
    wlib.dag.sortAndUnwrap {
      dag = config.appendFlag;
      mapIfOk =
        v:
        let
          esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
        in
        if builtins.isList v.data then builtins.concatStringsSep " " (map esc-fn v.data) else esc-fn v.data;
    }
  );

  bin-path = lib.escapeShellArg "${placeholder "out"}/bin/${config.binName}";

  wrapcmd = partial: ''
    echo ${lib.escapeShellArg partial} >> ${bin-path}
  '';
  shellcmdsdal =
    wlib.dag.lmap (var: esc-fn: wrapcmd "unset ${esc-fn var}") config.unsetVar
    ++ wlib.dag.mapDagToDal (
      n: v: esc-fn:
      wrapcmd "wrapperSetEnv ${esc-fn n} ${esc-fn v}"
    ) config.env
    ++ wlib.dag.mapDagToDal (
      n: v: esc-fn:
      wrapcmd "wrapperSetEnvDefault ${esc-fn n} ${esc-fn v}"
    ) config.envDefault
    ++ wlib.dag.lmap (
      tuple: esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
      in
      wrapcmd "wrapperPrefixEnv ${esc-fn env} ${esc-fn sep} ${esc-fn val}"
    ) config.prefixVar
    ++ wlib.dag.lmap (
      tuple: esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
      in
      wrapcmd "wrapperSuffixEnv ${esc-fn env} ${esc-fn sep} ${esc-fn val}"
    ) config.suffixVar
    ++ wlib.dag.lmap (
      tuple: esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperPrefixEnv ${esc-fn env} ${esc-fn sep} ";
      in
      ''echo ${lib.escapeShellArg cmd}"$(cat ${esc-fn val})" >> ${bin-path}''
    ) config.prefixContent
    ++ wlib.dag.lmap (
      tuple: esc-fn:
      let
        env = elemAt tuple 0;
        sep = elemAt tuple 1;
        val = elemAt tuple 2;
        cmd = "wrapperSuffixEnv ${esc-fn env} ${esc-fn sep} ";
      in
      ''echo ${lib.escapeShellArg cmd}"$(cat ${esc-fn val})" >> ${bin-path}''
    ) config.suffixContent
    ++ wlib.dag.lmap (dir: esc-fn: wrapcmd "cd ${esc-fn dir}") config.chdir
    ++ wlib.dag.lmap (cmd: _: wrapcmd cmd) config.runShell;

  luarc-path = "${placeholder "out"}/${config.binName}-rc.lua";
  arg0 = if config.argv0 == null then "\"$0\"" else config.escapingFunction config.argv0;
  finalcmd = ''${
    if config.exePath == "" then "${config.package}" else "${config.package}/${config.exePath}"
  } --cmd ${lib.escapeShellArg "source${luarc-path}"} ${preFlagStr} "$@" ${postFlagStr}'';

  luaEnv = (config.package.lua.withPackages or luajit.withPackages) config.settings.nvim_lua_env;
  NVIM_LUA_PATH = ((config.package.lua or luajit).pkgs.luaLib.genLuaPathAbsStr luaEnv);
  NVIM_LUA_CPATH = ((config.package.lua or luajit).pkgs.luaLib.genLuaCPathAbsStr luaEnv);

  manifest-path = lib.escapeShellArg "${placeholder "out"}/${config.binName}-rplugin.vim";
  shellcmds =
    isFinal:
    wlib.dag.sortAndUnwrap {
      dag =
        lib.optional isFinal {
          name = "NVIM_SYSTEM_RPLUGIN_MANIFEST";
          data = _: "${wrapcmd "wrapperSetEnvDefault NVIM_SYSTEM_RPLUGIN_MANIFEST ${manifest-path}"}";
        }
        ++ shellcmdsdal
        ++ [
          {
            name = "NIX_PROPAGATED_LUA_PATH";
            data =
              _:
              (wrapcmd "wrapperSuffixEnv LUA_PATH ';' ${lib.escapeShellArg NVIM_LUA_PATH}\n")
              + "echo \"wrapperSuffixEnv LUA_PATH ';' \${LUA_PATH@Q}\" >> ${bin-path}";
          }
          {
            name = "NIX_PROPAGATED_LUA_CPATH";
            data =
              _:
              (wrapcmd "wrapperSuffixEnv LUA_CPATH ';' ${lib.escapeShellArg NVIM_LUA_CPATH}\n")
              + "echo \"wrapperSuffixEnv LUA_CPATH ';' \${LUA_CPATH@Q}\" >> ${bin-path}";
          }
        ]
        ++ lib.optional isFinal {
          name = "NIX_GENERATED_VIMINIT";
          data =
            _:
            "${wrapcmd "wrapperSetEnvDefault VIMINIT 'lua require(${builtins.toJSON "${config.settings.info_plugin_name}.init_main"})'"}";
        }
        ++ lib.optional (isFinal && lib.isFunction config.argv0type) {
          name = "NIX_RUN_MAIN_PACKAGE";
          data = _: wrapcmd (config.argv0type finalcmd);
        };
      mapIfOk = v: v.data (if (v.esc-fn or null) != null then v.esc-fn else config.escapingFunction);
    };

  setvarfunc = /* bash */ ''wrapperSetEnv() { export "$1=$2"; }'';
  setvardefaultfunc = /* bash */ ''wrapperSetEnvDefault() { [ -z "''${!1+x}" ] && export "$1=$2"; }'';
  prefixvarfunc = /* bash */ ''wrapperPrefixEnv() { export "$1=''${!1:+$3$2}''${!1:-$3}"; }'';
  suffixvarfunc = /* bash */ ''wrapperSuffixEnv() { export "$1=''${!1:+''${!1}$2}$3"; }'';
  prefuncs = [
    setvardefaultfunc
    suffixvarfunc
  ]
  ++ lib.optional (config.env != { }) setvarfunc
  ++ lib.optional (config.prefixVar != [ ] || config.prefixContent != [ ]) prefixvarfunc;

in
if config.binName == "" then
  ""
else
  /* bash */ ''
    mkdir -p $out/bin
    { [ -e "$manifestLuaPath" ] && cat "$manifestLuaPath" || echo "$manifestLua"; } > ${lib.escapeShellArg luarc-path}
    echo ${lib.escapeShellArg "#!${bash}/bin/bash"} > ${bin-path}
    ${wrapcmd (builtins.concatStringsSep "\n" prefuncs)}
    ${builtins.concatStringsSep "\n" (shellcmds false)}
    ${wrapcmd "exec -a ${arg0} ${finalcmd}"}
    chmod +x ${bin-path}

    export NVIM_RPLUGIN_MANIFEST=${manifest-path}
    export HOME="$(mktemp -d)"
    if ! $out/bin/${config.binName} -i NONE -n -V1rplugins.log \
      +UpdateRemotePlugins +quit! > outfile 2>&1; then
      cat outfile
      echo -e "\nGenerating rplugin.vim failed!"
      exit 1
    fi
    { [ -e "$setupLuaPath" ] && cat "$setupLuaPath" || echo "$setupLua"; } ${maybe_compile}> ${lib.escapeShellArg luarc-path}
    echo ${lib.escapeShellArg "#!${bash}/bin/bash"} > ${bin-path}
    ${wrapcmd (builtins.concatStringsSep "\n" prefuncs)}
    ${builtins.concatStringsSep "\n" (shellcmds true)}
    ${lib.optionalString (!lib.isFunction config.argv0type) (wrapcmd "exec -a ${arg0} ${finalcmd}")}
    chmod +x ${bin-path}
  ''
