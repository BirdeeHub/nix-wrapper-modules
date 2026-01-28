{
  pkgs,
  nixosOptionsDoc,
  runCommand,
  lib,
  wlib,
  nixdoc,
  warningsAreErrors ? true,
  ...
}:
let
  buildModuleDocs =
    {
      prefix,
      include_core ? false,
    }:
    name: module:
    let
      # This gets you a list of each module, and those they import
      getGraph = import ./eval-graph.nix {
        inherit pkgs wlib;
        rootPath = wlib.modulesPath;
      };
      corelist = builtins.attrNames (wlib.evalModule { }).options;
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
      eval_mod =
        key: mod:
        wlib.evalModules {
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
        };
      module_description =
        if graph == [ ] then
          ""
        else
          lib.pipe graph [
            builtins.head
            (
              { key, file, ... }:
              {
                inherit file;
                descriptions = (eval_mod key file).config.meta.description;
              }
            )
            (
              { file, descriptions }:
              lib.findFirst (v: v.file == file) {
                pre = "";
                post = "";
              } descriptions
            )
          ];
      get_options = key: mod: {
        options = removeAttrs (eval_mod key mod).options corelist;
        inherit key;
      };
      optionsList =
        map (v: get_options v.key v.file) graph
        ++ lib.optional include_core {
          key = "lib/core.nix";
          options =
            removeAttrs
              (wlib.evalModule {
                inherit pkgs;
                package = lib.mkOverride 9001 pkgs.hello;
              }).options
              [ "_module" ];
        };
      mkMsg =
        key: doc:
        lib.optionalString (doc.optionsNix != { }) /* bash */ ''
          echo ${lib.escapeShellArg "## `${lib.removeSuffix "/module.nix" key}`:"} >> $out
          echo ${lib.escapeShellArg "<details open>"} >> $out
          echo ${lib.escapeShellArg "  <summary></summary>"} >> $out
          echo >> $out
          cat ${doc.optionsCommonMark} | \
            sed 's|file://${wlib.modulesPath}|https://github.com/BirdeeHub/nix-wrapper-modules/blob/main|g' | \
            sed 's|${wlib.modulesPath}|https://github.com/BirdeeHub/nix-wrapper-modules/blob/main|g' >> $out
          echo >> $out
          echo ${lib.escapeShellArg "</details>"} >> $out
          echo >> $out
        '';
      commands = map (
        v:
        mkMsg v.key (nixosOptionsDoc {
          inherit warningsAreErrors;
          inherit (v) options;
        })
      ) optionsList;
    in
    pkgs.runCommand "${name}-${prefix}-docs" { } (
      ''
        echo ${lib.escapeShellArg "# `${prefix}${name}`"} > $out
        echo >> $out
        echo ${lib.escapeShellArg module_description.pre} >> $out
        echo >> $out
        echo >> $out
      ''
      + (builtins.concatStringsSep "\n" commands)
      + "\n"
      + ''
        echo >> $out
        echo ${lib.escapeShellArg module_description.post} >> $out
      ''
    );

  module_docs = builtins.mapAttrs (buildModuleDocs { prefix = "wlib.modules."; }) wlib.modules;
  wrapper_docs = builtins.mapAttrs (buildModuleDocs {
    prefix = "wlib.wrapperModules.";
  }) wlib.wrapperModules;

  coredocs =
    let
      result = runCommand "core-wrapper-docs" { } (
        let
          evaled = wlib.evalModule {
            inherit pkgs;
            package = lib.mkOverride 9001 pkgs.hello;
          };
          desc = lib.findFirst (v: v.file == (toString wlib.core)) {
            pre = "";
            post = "";
          } evaled.config.meta.description;
          coreopts = nixosOptionsDoc {
            inherit warningsAreErrors;
            options = removeAttrs evaled.options [ "_module" ];
          };
        in
        ''
          echo ${lib.escapeShellArg desc.pre} > $out
          echo >> $out
          cat ${coreopts.optionsCommonMark} | \
            sed 's|file://${wlib.modulesPath}|https://github.com/BirdeeHub/nix-wrapper-modules/blob/main|g' | \
            sed 's|${wlib.modulesPath}|https://github.com/BirdeeHub/nix-wrapper-modules/blob/main|g' >> $out
          echo >> $out
          echo ${lib.escapeShellArg desc.post} >> $out
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
    echo '- [Lib Functions](./lib-intro.md)' >> $out/src/SUMMARY.md
    echo '  - [`wlib`](./wlib.md)' >> $out/src/SUMMARY.md
    echo '  - [`wlib.types`](./types.md)' >> $out/src/SUMMARY.md
    echo '  - [`wlib.dag`](./dag.md)' >> $out/src/SUMMARY.md
    echo '- [Core Options Set](./core.md)' >> $out/src/SUMMARY.md
    echo '- [`wlib.modules.default`](./default.md)' >> $out/src/SUMMARY.md
    echo '- [Helper Modules](./helper-modules.md)' >> $out/src/SUMMARY.md
    ${mkSubLinks (removeAttrs module_docs [ "default" ])}
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
