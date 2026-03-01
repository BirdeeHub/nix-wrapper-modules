maybe_compile:
{
  config,
  wlib,
  lib,
  luajit,
  makeWrapper,
  makeBinaryWrapper,
  dieHook,
  ...
}:
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
  split = wlib.makeWrapper.splitDal (
    wlib.makeWrapper.aggregateSingleOptionSet {
      inherit config;
      sortResult = false;
    }
  );
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
      mapArgs "add-flag" addFlag ++ mapArgs "append-flag" (wlib.dag.unwrapSort "appendFlag" appendFlag)
    )
  ];

  luarc-path = "${placeholder "out"}/${config.binName}-rc.lua";
  baseArgs = map lib.escapeShellArg [
    (if config.exePath == "" then "${config.package}" else "${config.package}/${config.exePath}")
    "${placeholder "out"}/${config.binDir or "bin"}/${config.binName}"
    "--add-flag"
    "--cmd"
    "--add-flag"
    "source${luarc-path}"
  ];
  luaEnv = (config.package.lua.withPackages or luajit.withPackages) config.settings.nvim_lua_env;
  NVIM_LUA_PATH = ((config.package.lua or luajit).pkgs.luaLib.genLuaPathAbsStr luaEnv);
  NVIM_LUA_CPATH = ((config.package.lua or luajit).pkgs.luaLib.genLuaCPathAbsStr luaEnv);
  manifest-path = lib.escapeShellArg "${placeholder "out"}/${config.binName}-rplugin.vim";
  makeWrapperCmd =
    isFinal:
    lib.pipe split.other [
      (
        val:
        lib.optional isFinal {
          name = "NVIM_SYSTEM_RPLUGIN_MANIFEST";
          esc-fn = lib.escapeShellArg;
          attr-name = "NVIM_SYSTEM_RPLUGIN_MANIFEST";
          type = "envDefault";
          data = manifest-path;
        }
        ++ val
        ++ [
          {
            name = "NIX_PROPAGATED_LUA_PATH";
            esc-fn = x: x;
            type = "UNPROCESSED";
            data = [
              "--suffix"
              "LUA_PATH"
              "';'"
              "${lib.escapeShellArg NVIM_LUA_PATH}"
              "--suffix"
              "LUA_PATH"
              "';'"
              "\"$LUA_PATH\""
            ];
          }
          {
            name = "NIX_PROPAGATED_LUA_CPATH";
            esc-fn = x: x;
            type = "UNPROCESSED";
            data = [
              "--suffix"
              "LUA_CPATH"
              "';'"
              "${lib.escapeShellArg NVIM_LUA_CPATH}"
              "--suffix"
              "LUA_CPATH"
              "';'"
              "\"$LUA_CPATH\""
            ];
          }
        ]
        ++ lib.optional isFinal {
          name = "NIX_GENERATED_VIMINIT";
          type = "envDefault";
          esc-fn = lib.escapeShellArg;
          attr-name = "VIMINIT";
          data = "lua require(${builtins.toJSON "${config.settings.info_plugin_name}.init_main"})";
        }
      )
      (wlib.dag.unwrapSort "makeWrapper")
      (builtins.concatMap (
        v:
        let
          esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
          esc-list = map esc-fn;
        in
        if v.type or null == "unsetVar" then
          [ "--unset" ] ++ [ (esc-fn v.data) ]
        else if v.type or null == "env" then
          [ "--set" ]
          ++ esc-list [
            v.attr-name
            v.data
          ]
        else if v.type or null == "envDefault" then
          [ "--set-default" ]
          ++ esc-list [
            v.attr-name
            v.data
          ]
        else if v.type or null == "UNPROCESSED" then
          v.data
        else if v.type or null == "prefixVar" then
          [ "--prefix" ] ++ esc-list v.data
        else if v.type or null == "suffixVar" then
          [ "--suffix" ] ++ esc-list v.data
        else if v.type or null == "chdir" then
          [ "--chdir" ] ++ [ (esc-fn v.data) ]
        else if config.wrapperImplementation or null != "binary" then
          if v.type or null == "prefixContent" then
            [ "--prefix-contents" ] ++ esc-list v.data
          else if v.type or null == "suffixContent" then
            [ "--suffix-contents" ] ++ esc-list v.data
          else if v.type or null == "runShell" then
            [ "--run" ] ++ [ (esc-fn v.data) ]
          else
            [ ]
        else
          [ ]
      ))
      (res: [ "makeWrapper" ] ++ baseArgs ++ argv0 ++ cliArgs ++ res)
      (builtins.concatStringsSep " ")
    ];

  srcsetup = p: "source ${lib.escapeShellArg "${p}/nix-support/setup-hook"}";
in
if
  !builtins.isString (config.binName or null)
  || config.binName == ""
  || !(lib.isStringLike (config.package or null))
then
  ""
else
  /* bash */ ''
    (
      OLD_OPTS="$(set +o)"
      ${srcsetup dieHook}
      ${srcsetup (if config.wrapperImplementation == "binary" then makeBinaryWrapper else makeWrapper)}
      eval "$OLD_OPTS"
      mkdir -p $out/bin
      { [ -e "$manifestLuaPath" ] && cat "$manifestLuaPath" || echo "$manifestLua"; } > ${lib.escapeShellArg luarc-path}
      export NVIM_RPLUGIN_MANIFEST=${manifest-path}
      export HOME="$(mktemp -d)"
      ${makeWrapperCmd false}

      if ! $out/bin/${config.binName} -i NONE -n -V1rplugins.log \
        +UpdateRemotePlugins +quit! > outfile 2>&1; then
        cat outfile
        echo -e "\nGenerating rplugin.vim failed!"
        exit 1
      fi
      rm -f "$out/bin/${config.binName}"
      { [ -e "$setupLuaPath" ] && cat "$setupLuaPath" || echo "$setupLua"; } ${maybe_compile}> ${lib.escapeShellArg luarc-path}
      ${makeWrapperCmd true}
    )
  ''
