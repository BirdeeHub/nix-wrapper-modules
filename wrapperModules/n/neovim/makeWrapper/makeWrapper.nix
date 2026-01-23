maybe_compile:
{
  config,
  wlib,
  lib,
  luajit,
  dieHook,
  makeWrapper,
  makeBinaryWrapper,
  ...
}:
let
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
        "--add-flag"
        name
      ]
    else if lib.trim flagSeparator == "" && flagSeparator != "" then
      [
        "--add-flag"
        name
        "--add-flag"
        (toString value)
      ]
    else
      [
        "--add-flag"
        "${name}${flagSeparator}${toString value}"
      ];

  argv0 = [
    (
      if builtins.isString config.argv0 then
        {
          data = [
            "--argv0"
            config.argv0
          ];
        }
      else if config.argv0type == "resolve" then
        { data = [ "--resolve-argv0" ]; }
      else
        { data = [ "--inherit-argv0" ]; }
    )
  ];
  envVarsDefault = lib.optionals (config.envDefault != { }) (
    wlib.dag.mapDagToDal (n: v: [
      "--set-default"
      n
      (toString v)
    ]) config.envDefault
  );
  envVars = lib.optionals (config.env != { }) (
    wlib.dag.mapDagToDal (n: v: [
      "--set"
      n
      (toString v)
    ]) config.env
  );
  flags = lib.optionals (config.flags != { }) (
    generateArgsFromFlags (config.flagSeparator or " ") config.flags
  );
  mapargs =
    n: argname: single:
    wlib.dag.lmap (
      v:
      if builtins.isList v then
        if single then
          lib.concatMap (val: [
            "--${argname}"
            (toString val)
          ]) v
        else
          [ "--${argname}" ] ++ v
      else
        [
          "--${argname}"
          (toString v)
        ]
    ) config.${n};

  other =
    mapargs "unsetVar" "unset" true
    ++ mapargs "chdir" "chdir" true
    ++ mapargs "prefixVar" "prefix" false
    ++ mapargs "suffixVar" "suffix" false;
  conditionals =
    if config.wrapperImplementation != "binary" then
      mapargs "runShell" "run" true
      ++ mapargs "prefixContent" "prefix-contents" false
      ++ mapargs "suffixContent" "suffix-contents" false
    else
      [ ];

  finalArgs =
    argv0
    ++ mapargs "addFlag" "add-flag" true
    ++ flags
    ++ mapargs "appendFlag" "append-flag" true
    ++ envVars
    ++ envVarsDefault
    ++ other
    ++ conditionals;

  luarc-path = "${placeholder "out"}/${config.binName}-rc.lua";
  baseArgs = lib.escapeShellArgs [
    (if config.exePath == "" then "${config.package}" else "${config.package}/${config.exePath}")
    "${placeholder "out"}/bin/${config.binName}"
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
    lib.pipe finalArgs [
      (
        val:
        lib.optional isFinal {
          name = "NVIM_SYSTEM_RPLUGIN_MANIFEST";
          esc-fn = x: x;
          data = "--set-default NVIM_SYSTEM_RPLUGIN_MANIFEST ${manifest-path}";
        }
        ++ val
        ++ [
          {
            name = "NIX_PROPAGATED_LUA_PATH";
            esc-fn = x: x;
            data =
              "--suffix LUA_PATH ';' ${lib.escapeShellArg NVIM_LUA_PATH} "
              + "--suffix LUA_PATH ';' \"$LUA_PATH\"";
          }
          {
            name = "NIX_PROPAGATED_LUA_CPATH";
            esc-fn = x: x;
            data =
              "--suffix LUA_CPATH ';' ${lib.escapeShellArg NVIM_LUA_CPATH} "
              + "--suffix LUA_CPATH ';' \"$LUA_CPATH\"";
          }
        ]
        ++ lib.optional isFinal {
          name = "NIX_GENERATED_VIMINIT";
          esc-fn = x: x;
          data = "--set-default VIMINIT 'lua require(${builtins.toJSON "${config.settings.info_plugin_name}.init_main"})'";
        }
      )
      (wlib.dag.unwrapSort "makeWrapper")
      (map (
        v:
        let
          esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
        in
        if builtins.isList v.data then map esc-fn v.data else esc-fn v.data
      ))
      lib.flatten
      (
        v:
        [
          "makeWrapper"
          baseArgs
        ]
        ++ v
      )
      (builtins.concatStringsSep " ")
    ];
  srcsetup = p: "source ${lib.escapeShellArg "${p}/nix-support/setup-hook"}";
in
if config.binName == "" then
  ""
else
  /* bash */ ''
    (
      ${srcsetup dieHook}
      ${srcsetup (if config.wrapperImplementation == "binary" then makeBinaryWrapper else makeWrapper)}
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
