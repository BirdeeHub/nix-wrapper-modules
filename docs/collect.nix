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
  corelist = builtins.attrNames (wlib.evalModule { }).options;
  evaluate_helpers =
    mp:
    (wlib.evalModules {
      modules = [
        { _module.check = false; }
        mp
        {
          inherit pkgs;
          package = pkgs.hello;
        }
      ];
    }).options;
  evaluate =
    mp:
    (wlib.evalModules {
      modules = [
        { _module.check = false; }
        mp
        { inherit pkgs; }
      ];
    }).options;
  coredocs =
    let
      result = runCommand "core-wrapper-docs" { } (
        let
          coreopts = nixosOptionsDoc {
            options =
              let
                opts = (
                  builtins.removeAttrs
                    (wlib.evalModule {
                      inherit pkgs;
                      package = pkgs.hello;
                    }).options
                    [ "_module" ]
                );
              in
              opts
              // {
                meta = opts.meta // {
                  platforms = opts.meta.platforms // {
                    # mimic an option but dont show the whole damn systems list
                    type = lib.types.listOf lib.types.str;
                    default = [ "... lib.platforms.all ..." ];
                    example = ''[ "x86_64-linux" "aarch64-linux" ]'';
                  };
                };
              };
          };
        in
        ''
          cat ${./core.md} > $out
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

  to_remove = builtins.attrNames (wlib.evalModule { imports = [ wlib.modules.default ]; }).options;
  wrapperdocs = builtins.mapAttrs (
    name: mod:
    let
      optionsDoc = nixosOptionsDoc {
        options = builtins.removeAttrs (evaluate mod) corelist; # TODO: find a way to toggle with and without the difference between corelist and to_remove in mdbook
      };
    in
    runCommand "${name}-wrapper-docs" { } ''
      echo '# `wlib.wrapperModules.${name}`' > $out
      echo >> $out
      echo >> $out
      cat ${optionsDoc.optionsCommonMark} | \
        sed 's|file://${../.}|https://github.com/BirdeeHub/nix-wrapper-modules/blob/main|g' | \
        sed 's|${../.}|https://github.com/BirdeeHub/nix-wrapper-modules/blob/main|g' >> $out
    ''
  ) wlib.wrapperModules;

  module_desc = {
    makeWrapperNix = ''
      A partial and experimental pure nix implementation of the `makeWrapper` interface

      Allows expansion of variables at runtime in flags and environment variable values
    '';
    makeWrapper = ''
      An implementation of the `makeWrapper` interface via type safe module options.

      Imported by `wlib.modules.default`
    '';
    makeWrapperBase = ''
      Takes dependency lists of wrapper arguments of escaped and unescaped varieties,
      and sorts them according to their listed dependencies, if any.

      Imported by `wlib.modules.makeWrapper`
    '';
    symlinkScript = ''
      Adds extra options compared to the default `symlinkScript` option value.

      Imported by `wlib.modules.default`
    '';
    default = ''
      This module imports both `wlib.modules.makeWrapper` and `wlib.modules.symlinkScript` for convenience
    '';
  };

  moduledocs = builtins.mapAttrs (
    name: mod:
    let
      optionsDoc = nixosOptionsDoc {
        options = builtins.removeAttrs (evaluate_helpers mod) corelist;
      };
    in
    runCommand "${name}-wrapper-docs" { } ''
      echo '# `wlib.modules.${name}`' > $out
      echo >> $out
      ${
        if builtins.isString (module_desc.${name} or null) then
          "echo " + lib.escapeShellArg module_desc.${name} + " >> $out"
        else
          ""
      }
      echo >> $out
      cat ${optionsDoc.optionsCommonMark} | \
        sed 's|file://${../.}|https://github.com/BirdeeHub/nix-wrapper-modules/blob/main|g' | \
        sed 's|${../.}|https://github.com/BirdeeHub/nix-wrapper-modules/blob/main|g' >> $out
    ''
  ) wlib.modules;

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
    ${mkCopyCmds (coredocs // wrapperdocs // moduledocs // libdocs)}
    cp ${./helper-modules.md} $out/src/helper-modules.md
    cp ${./wrapper-modules.md} $out/src/wrapper-modules.md
    cp ${./lib-intro.md} $out/src/lib-intro.md
    cat ${../README.md} | sed 's|# \[nix-wrapper-modules\](https://birdeehub.github.io/nix-wrapper-modules/)|# [nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules)|' >> $out/src/home.md
    echo '# Summary' > $out/src/SUMMARY.md
    echo >> $out/src/SUMMARY.md
    echo '- [Intro](./home.md)' >> $out/src/SUMMARY.md
    echo '- [Core Options Set](./core.md)' >> $out/src/SUMMARY.md
    echo '- [`wlib.modules.default`](./default.md)' >> $out/src/SUMMARY.md
    echo '- [Lib Functions](./lib-intro.md)' >> $out/src/SUMMARY.md
    echo '  - [`wlib`](./wlib.md)' >> $out/src/SUMMARY.md
    echo '  - [`wlib.dag`](./dag.md)' >> $out/src/SUMMARY.md
    echo '  - [`wlib.types`](./types.md)' >> $out/src/SUMMARY.md
    echo '- [Helper Modules](./helper-modules.md)' >> $out/src/SUMMARY.md
    ${mkSubLinks (builtins.removeAttrs moduledocs [ "default" ])}
    echo '- [Wrapper Modules](./wrapper-modules.md)' >> $out/src/SUMMARY.md
    ${mkSubLinks wrapperdocs}
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
