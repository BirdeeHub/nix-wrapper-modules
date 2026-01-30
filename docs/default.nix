{
  pkgs,
  runCommand,
  lib,
  wlib,
  nixdoc,
  writeShellScriptBin,
  ...
}:
let
  inherit (import ./per-mod { inherit lib wlib; }) wrapperModuleMD;
  buildModuleDocs =
    {
      prefix ? "",
      title ? null,
      package ? null,
      includeCore ? true,
      descriptionStartsOpen ? null,
      descriptionIncluded ? null,
      moduleStartsOpen ? null,
    }:
    name: module:
    runCommand "${name}-${prefix}-docs"
      {
        passAsFile = [ "modDoc" ];
        modDoc = wrapperModuleMD (
          wlib.evalModule [
            module
            {
              _module.check = false;
              inherit pkgs;
              ${if package != null then "package" else null} = package;
            }
          ]
          // {
            inherit includeCore;
            ${if descriptionStartsOpen != null then "descriptionStartsOpen" else null} = descriptionStartsOpen;
            ${if descriptionIncluded != null then "descriptionIncluded" else null} = descriptionIncluded;
            ${if moduleStartsOpen != null then "moduleStartsOpen" else null} = moduleStartsOpen;
          }
        );
      }
      ''
        echo ${lib.escapeShellArg (if title != null then "# ${title}" else "# `${prefix}${name}`")} > $out
        echo >> $out
        cat "$modDocPath" >> $out
      '';

  module_docs = builtins.mapAttrs (buildModuleDocs {
    prefix = "wlib.modules.";
    package = pkgs.hello;
    includeCore = false;
    moduleStartsOpen = _: _: true;
    descriptionStartsOpen =
      _: _: _:
      true;
    descriptionIncluded =
      _: _: _:
      true;
  }) wlib.modules;
  wrapper_docs = builtins.mapAttrs (buildModuleDocs {
    prefix = "wlib.wrapperModules.";
  }) wlib.wrapperModules;
  coredocs = {
    core = buildModuleDocs {
      prefix = "";
      package = pkgs.hello;
      title = "Core (builtin) Options set";
    } "core" wlib.core;
  };

  libdocs = {
    dag = runCommand "wrapper-dag-docs" { } ''
      ${nixdoc}/bin/nixdoc --category "dag" --description '`wlib.dag` set documentation' --file ${../lib/dag.nix} --prefix "wlib" >> $out
    '';
    wlib = runCommand "wrapper-lib-docs" { } ''
      ${nixdoc}/bin/nixdoc --category "" --description '`wlib` main set documentation' --file ${../lib/lib.nix} --prefix "wlib" >> $out
    '';
    types = runCommand "wrapper-types-docs" { } ''
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

  combined = runCommand "book_src" { } ''
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
  book = runCommand "book_drv" { } ''
    mkdir -p $out
    ${pkgs.mdbook}/bin/mdbook build ${combined} -d $out
  '';
in
writeShellScriptBin "copy-docs" ''
  target=''${1:-./_site}
  mkdir -p $target
  cp -rf ${book}/* $target
  chmod -R u+rwX "$target"
''
