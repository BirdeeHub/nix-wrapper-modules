{
  opt_dir,
  start_dir,
  specs,
  specMaps,
  info_plugin_name,
  wlib,
  lib,
  ...
}:
let
  mappedSpecs = lib.pipe specs (
    [
      (lib.mapAttrsToList (
        name: value:
        if builtins.isList value.data then
          {
            inherit name value;
            type = "parent";
          }
        else
          {
            inherit name value;
            type = "spec";
          }
      ))
      (lib.concatMap (
        item:
        if item.type == "parent" then
          [
            (
              item
              // {
                value = item.value // {
                  data = null;
                };
              }
            )
          ]
          ++ map (child: {
            name = item.name;
            value = child;
            type = "spec";
          }) item.value.data
        else
          [ item ]
      ))
    ]
    ++ (lib.pipe specMaps [
      (wlib.dag.unwrapSort "specMaps DAL")
      (builtins.filter (v: (v.enable or true)))
      (map (v: v.data))
    ])
    ++ [
      (builtins.filter (v: v ? name && v ? value && v ? type))
      (lib.partition (v: v.type == "parent"))
      (
        v:
        let
          parents = lib.pipe v.right [
            (map (v: {
              ${v.name} = v.value;
            }))
            (builtins.zipAttrsWith (
              name: values:
              if builtins.length values > 1 then
                throw "more than one parent per list not allowed"
              else
                builtins.head values
            ))
          ];
        in
        lib.pipe v.wrong [
          (map (v: {
            ${v.name} = v.value;
          }))
          (builtins.zipAttrsWith (name: values: values))
          (builtins.mapAttrs (
            n: v:
            if parents ? "${n}" then
              parents.${n} // { data = v; }
            else if builtins.length v == 1 then
              builtins.head v
            else
              { data = v; }
          ))
          (attrs: parents // attrs)
          (wlib.dag.unwrapSort "parents of config and plugin DAG")
          (map (
            v:
            if builtins.isList (v.data or null) then
              [
                (
                  v
                  // {
                    data = null;
                    after = [ ];
                    before = [ ];
                  }
                )
              ]
              ++ v.data
              ++ [
                {
                  inherit (v) name;
                  data = null;
                }
              ]
            else
              v
          ))
          lib.flatten
        ]
      )
      (
        pluginsDal:
        [
          {
            name = "INIT_MAIN";
            data = null;
            type = "lua";
            config = /* lua */ ''
              local cfgdir = (require(${builtins.toJSON info_plugin_name}).settings or {}).config_directory
              if cfgdir then
                if vim.fn.filereadable(cfgdir .. "/init.lua") == 1 then
                  dofile(cfgdir .. "/init.lua")
                elseif vim.fn.filereadable(cfgdir .. "/init.vim") == 1 then
                  vim.cmd.source(cfgdir .. "/init.vim")
                end
              end
            '';
          }
        ]
        ++ pluginsDal
        ++ [
          {
            name = "SPECS_END";
            data = null;
            after = [ "INIT_MAIN" ];
          }
        ]
      )
      (builtins.filter (v: if v ? enable then v.enable else true))
      (wlib.dag.unwrapSort "config and plugin DAG")
    ]
  );

  getNameFromSpec =
    v:
    if v.pname or null != null then
      v.pname
    else if v.data.pname or null != null then
      v.data.pname
    else if v.data.meta.mainProgram or null != null then
      v.data.meta.mainProgram
    else if v.data.name or null != null then
      v.data.name
    else if wlib.types.stringable.check (v.data or null) then
      if baseNameOf (v.data or "") != "" then
        baseNameOf v.data
      else if lib.getName (v.data or "") != "" then
        baseNameOf v.data
      else
        null
    else if v.name or null != null then
      v.name
    else
      null;

  # returns a list of [ { name, data, lazy } ]
  allPlugins = lib.pipe mappedSpecs [
    (builtins.filter (v: v.data or null != null))
    (map (v: {
      inherit (v) data;
      lazy = v.lazy or false;
      name =
        let
          name = getNameFromSpec v;
        in
        if name != null then
          name
        else
          throw ''
            Error: wrapperModules.neovim:
            Provided a string type plugin path with empty basename and no pname provided!
            As there is no derivation for this plugin and only a path,
            there is no way to know the name to use for the plugin.

            Offending plugin path: ${lib.escapeShellArg v.data}

            Please set `{ pname = "pluginname"; data = theplugin; }`
          '';
    }))
  ];

  hasFennel = builtins.any (v: v.type or null == "fnl") mappedSpecs;

  toLua = lib.generators.toLua { };

  mapForLang =
    type: cfg: info: name: lazy:
    let
      initial =
        if type == "vim" then
          "vim.cmd((${toLua ''
            function! s:nixWrapperTempFunc(...)
              ${cfg}
            endfunction
            call call('s:nixWrapperTempFunc', %s)
            delfunction s:nixWrapperTempFunc
          ''}):format(vim.fn.string({${info}, ${name}, ${lazy}})));"
        else if type == "lua" then
          "do\n(function(...)\n${cfg}\nend)(${info}, ${name}, ${lazy})\nend"
        else
          "((fn [...]\n${cfg}\n) (lua \"\" ${builtins.toJSON info}) ${name} ${lazy})";
    in
    if hasFennel && type != "fnl" then "(lua ${builtins.toJSON initial})" else initial;

in
{
  inherit hasFennel mappedSpecs;
  infoPluginInitMain = lib.pipe mappedSpecs [
    (builtins.filter (v: v.config or null != null && v.config or "" != ""))
    (map (
      v:
      let
        name = getNameFromSpec v;
        lazy = v.lazy or null;
      in
      mapForLang (v.type or null) (v.config or "") (toLua (v.info or { })) (toLua name) (toLua lazy)
    ))
    (builtins.concatStringsSep "\n")
  ];

  buildPackDir = lib.pipe allPlugins [
    (map (
      v:
      "ln -s ${lib.escapeShellArg v.data} ${lib.escapeShellArg "${if v.lazy then opt_dir else start_dir}/${v.name}"}"
    ))
    (builtins.concatStringsSep "\n")
  ];

  plugins = lib.pipe allPlugins (
    let
      foldplugins = (builtins.foldl' (acc: v: acc // { ${v.name} = v.data; }) { });
    in
    [
      (lib.partition (p: p.lazy))
      (v: {
        lazy = foldplugins v.right;
        start = foldplugins v.wrong;
      })
    ]
  );
}
