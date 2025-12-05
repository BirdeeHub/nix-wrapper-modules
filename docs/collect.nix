{
  pkgs,
  nixosOptionsDoc,
  runCommand,
  lib,
  wlib,
  nixdoc,
  ...
}:
let
  # This gets you a list of each module, and those they import
  getGraph = import ./eval-graph.nix {
    inherit pkgs wlib;
    rootPath = ../.;
  };
  corelist = builtins.attrNames (wlib.evalModule { }).options;
  buildModuleDocs =
    prefix: descriptions: name: module:
    let
      graph = getGraph module;
      maineval = wlib.evalModules {
        modules = [
          { _module.check = false; }
          module
          {
            inherit pkgs;
            package = lib.mkOverride 9001 pkgs.hello;
          }
        ];
      };
      package = maineval.config.package;
      get_options =
        key: mod:
        builtins.removeAttrs
          (wlib.evalModules {
            modules = [
              { _module.check = false; }
              {
                disabledModules = map (v: v.key) (
                  builtins.filter (v: v.key != key && builtins.match ".*:anon-[0-9]+" v.key == null) graph
                );
                imports = [ mod ];
                config.pkgs = pkgs;
                config.package = lib.mkOverride 9001 package;
              }
            ];
          }).options
          corelist;
      options = map (v: get_options v.key v.file) graph;
      optdocs = map (v: (nixosOptionsDoc { options = v; }).optionsCommonMark) options;
      commands = map (v: /* bash */ ''
        cat ${v} | \
          sed 's|file://${../.}|https://github.com/BirdeeHub/nix-wrapper-modules/blob/main|g' | \
          sed 's|${../.}|https://github.com/BirdeeHub/nix-wrapper-modules/blob/main|g' >> $out
      '') optdocs;
    in
    pkgs.runCommand "${name}-${prefix}-docs" { } (
      ''
        echo '# `wlib.${prefix}.${name}`' > $out
        echo >> $out
        echo ${lib.escapeShellArg (descriptions.${name} or "")} >> $out
        echo >> $out
      ''
      + (builtins.concatStringsSep " " commands)
    );

  read_md_dir =
    dir:
    let
      files = builtins.readDir dir;
      mdFiles = builtins.filter (name: builtins.match ".*\\.md$" name != null) (builtins.attrNames files);
    in
    builtins.listToAttrs (
      map (name: {
        name = builtins.substring 0 (builtins.stringLength name - 3) name;
        value = builtins.readFile (dir + "/${name}");
      }) mdFiles
    );
  module_desc = read_md_dir ./modules;
  module_docs = builtins.mapAttrs (buildModuleDocs "modules" (
    builtins.removeAttrs module_desc [ "core" ]
  )) wlib.modules;
  wrapper_docs = builtins.mapAttrs (buildModuleDocs "wrapperModules" { }) wlib.wrapperModules;

  coredocs =
    let
      result = runCommand "core-wrapper-docs" { } (
        let
          coreopts = nixosOptionsDoc {
            options =
              builtins.removeAttrs
                (wlib.evalModule {
                  inherit pkgs;
                  package = lib.mkOverride 9001 pkgs.hello;
                }).options
                [ "_module" ];
          };
        in
        ''
          echo ${lib.escapeShellArg (module_desc.core or "")} > $out
          echo >> $out
          cat ${coreopts.optionsCommonMark} | \
            sed 's|file://${../.}|https://github.com/BirdeeHub/nix-wrapper-modules/blob/main|g' | \
            sed 's|${../.}|https://github.com/BirdeeHub/nix-wrapper-modules/blob/main|g' >> $out
        ''
      );
    in
    {
      core = result;
    };

  libdocs = {
    dag = pkgs.runCommand "wrapper-dag-docs" { } ''
      ${nixdoc}/bin/nixdoc --category "dag" --description '`wlib.dag` set documentation' --file ${../lib/dag.nix} --prefix "wlib" >> $out
    '';
    wlib = pkgs.runCommand "wrapper-lib-docs" { } ''
      ${nixdoc}/bin/nixdoc --category "" --description '`wlib` main set documentation' --file ${../lib/lib.nix} --prefix "wlib" >> $out
    '';
    types = pkgs.runCommand "wrapper-types-docs" { } ''
      ${nixdoc}/bin/nixdoc --category "types" --description '`wlib.types` set documentation' --file ${../lib/types.nix} --prefix "wlib" >> $out
    '';
  };

  mkCopyCmds = lib.flip lib.pipe [
    (lib.mapAttrsToList (
      n: v: {
        name = n;
        value = v;
      }
    ))
    (builtins.filter (v: v.value ? outPath))
    (map (v: ''
      cp -r ${v.value} $out/src/${v.name}.md
    ''))
    (builtins.concatStringsSep "\n")
  ];
  mkSubLinks = lib.flip lib.pipe [
    builtins.attrNames
    (map (n: ''
      echo '  - [${n}](./${n}.md)' >> $out/src/SUMMARY.md
    ''))
    (builtins.concatStringsSep "\n")
  ];

  combined = pkgs.runCommand "book_src" { } ''
    mkdir -p $out/src
    cp ${./book.toml} $out/book.toml
    ${mkCopyCmds (coredocs // wrapper_docs // module_docs // libdocs)}
    cp ${./md}/* $out/src/
    cat ${../README.md} | sed 's|# \[nix-wrapper-modules\](https://birdeehub.github.io/nix-wrapper-modules/)|# [nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules)|' >> $out/src/home.md
    echo '# Summary' > $out/src/SUMMARY.md
    echo >> $out/src/SUMMARY.md
    echo '- [Intro](./home.md)' >> $out/src/SUMMARY.md
    echo '- [Getting Started](./getting-started.md)' >> $out/src/SUMMARY.md
    echo '- [Core Options Set](./core.md)' >> $out/src/SUMMARY.md
    echo '- [`wlib.modules.default`](./default.md)' >> $out/src/SUMMARY.md
    echo '- [Lib Functions](./lib-intro.md)' >> $out/src/SUMMARY.md
    echo '  - [`wlib`](./wlib.md)' >> $out/src/SUMMARY.md
    echo '  - [`wlib.dag`](./dag.md)' >> $out/src/SUMMARY.md
    echo '  - [`wlib.types`](./types.md)' >> $out/src/SUMMARY.md
    echo '- [Helper Modules](./helper-modules.md)' >> $out/src/SUMMARY.md
    ${mkSubLinks (
      builtins.removeAttrs module_docs [
        "default"
        "core"
      ]
    )}
    echo '- [Wrapper Modules](./wrapper-modules.md)' >> $out/src/SUMMARY.md
    ${mkSubLinks wrapper_docs}
  '';
  book = pkgs.runCommand "book_drv" { } ''
    mkdir -p $out
    ${pkgs.mdbook}/bin/mdbook build ${combined} -d $out
  '';
in
pkgs.writeShellScriptBin "copy-docs" ''
  target=''${1:-./docs/generated}
  mkdir -p $target
  cp -rf ${book}/* $target
''
