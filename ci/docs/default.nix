{
  config,
  lib,
  wlib,
  pkgs,
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
      warningsAreErrors ? true,
    }:
    name: module:
    (if title != null then "# ${title}\n\n" else "# `${prefix}${name}`\n\n")
    + wrapperModuleMD (
      wlib.evalModule [
        module
        {
          _module.check = false;
          inherit pkgs;
          ${if package != null then "package" else null} = package;
        }
      ]
      // {
        inherit includeCore warningsAreErrors;
        ${if descriptionStartsOpen != null then "descriptionStartsOpen" else null} = descriptionStartsOpen;
        ${if descriptionIncluded != null then "descriptionIncluded" else null} = descriptionIncluded;
        ${if moduleStartsOpen != null then "moduleStartsOpen" else null} = moduleStartsOpen;
      }
    );

in
{
  imports = [
    wlib.wrapperModules.mdbook
    ./redirects.nix
  ];
  config.mainBook = "nix-wrapper-modules";
  config.outputs = [
    "out"
    "generated"
  ];
  options.warningsAreErrors = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether warnings in the docgen should be treated as errors (i.e. missing descriptions)";
  };
  config.drv.unsafeDiscardReferences.generated = true;
  config.drv.preBuild = ''
    mkdir -p "$generated/wrapper_docs"
    jq -r '.wrapper_docs | to_entries[] | @base64' "$NIX_ATTRS_JSON_FILE" | while read -r entry; do
      # decode base64 to get JSON safely
      decoded=$(echo "$entry" | base64 --decode)
      echo "$(echo "$decoded" | jq -r '.value')" > "$generated/wrapper_docs/$(echo "$decoded" | jq -r '.key').md"
    done
    mkdir -p "$generated/module_docs"
    jq -r '.module_docs | to_entries[] | @base64' "$NIX_ATTRS_JSON_FILE" | while read -r entry; do
      decoded="$(echo "$entry" | base64 --decode)"
      echo "$(echo "$decoded" | jq -r '.value')" > "$generated/module_docs/$(echo "$decoded" | jq -r '.key').md"
    done
  '';
  config.drv.module_docs = builtins.mapAttrs (buildModuleDocs {
    prefix = "wlib.modules.";
    package = pkgs.hello;
    includeCore = false;
    inherit (config) warningsAreErrors;
    moduleStartsOpen = _: _: true;
    descriptionStartsOpen =
      _: _: _:
      true;
    descriptionIncluded =
      _: _: _:
      true;
  }) wlib.modules;
  config.drv.wrapper_docs = builtins.mapAttrs (buildModuleDocs {
    prefix = "wlib.wrapperModules.";
    inherit (config) warningsAreErrors;
  }) wlib.wrapperModules;
  config.drv.core_docs = buildModuleDocs {
    package = pkgs.hello;
    inherit (config) warningsAreErrors;
    title = "Core (builtin) Options set";
  } "core" { };
  config.books.nix-wrapper-modules = {
    book = {
      book = {
        src = "src";
        authors = [ "BirdeeHub" ];
        language = "en";
        title = "nix-wrapper-modules";
        description = "Make wrapper derivations with the module system! Use the existing modules, or write your own!";
      };
      output.html.git-repository-url = "https://github.com/BirdeeHub/nix-wrapper-modules";
    };
    summary = [
      {
        data = "title";
        name = "nix-wrapper-modules";
      }
      {
        name = "Intro";
        data = "numbered";
        path = "md/intro.md";
        src = "${placeholder "out"}/wrappers-lib/intro.md";
        build = ''
          mkdir -p $out/wrappers-lib
          sed 's|# \[nix-wrapper-modules\](https://birdeehub.github.io/nix-wrapper-modules/)|# [nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules)|' < '${../../README.md}' > "$out/wrappers-lib/intro.md"
        '';
      }
      {
        name = "Getting Started";
        data = "numbered";
        path = "md/getting-started.md";
        src = ./md/getting-started.md;
      }
      {
        name = "Lib Functions";
        data = "numbered";
        path = "md/lib-intro.md";
        src = ./md/lib-intro.md;
        subchapters = [
          {
            name = "wlib";
            data = "numbered";
            path = "lib/wlib.md";
            src = "${placeholder "out"}/wrappers-lib/wlib.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "" --description '`wlib` main set documentation' --file '${../../lib/lib.nix}' --prefix "wlib" >> $out/wrappers-lib/wlib.md
            '';
          }
          {
            name = "types";
            data = "numbered";
            path = "lib/types.md";
            src = "${placeholder "out"}/wrappers-lib/types.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "types" --description '`wlib.types` set documentation' --file '${../../lib/types.nix}' --prefix "wlib" >> $out/wrappers-lib/types.md
            '';
          }
          {
            name = "dag";
            data = "numbered";
            path = "lib/dag.md";
            src = "${placeholder "out"}/wrappers-lib/dag.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "dag" --description '`wlib.dag` set documentation' --file '${../../lib/dag.nix}' --prefix "wlib" >> $out/wrappers-lib/dag.md
            '';
          }
        ];
      }
      {
        name = "Core Options Set";
        data = "numbered";
        path = "lib/core.md";
        build = ''
          jq -r '.core_docs' "$NIX_ATTRS_JSON_FILE" > "$generated/core.md"
        '';
        src = "${placeholder "generated"}/core.md";
      }
      {
        name = "`wlib.modules.default`";
        data = "numbered";
        path = "modules/default.md";
        src = "${placeholder "generated"}/module_docs/default.md";
      }
      {
        name = "Helper Modules";
        data = "numbered";
        path = "md/helper-modules.md";
        src = ./md/helper-modules.md;
        subchapters = lib.pipe config.drv.module_docs [
          (v: removeAttrs v [ "default" ])
          builtins.attrNames
          (map (n: {
            name = n;
            data = "numbered";
            path = "modules/${n}.md";
            src = "${placeholder "generated"}/module_docs/${n}.md";
          }))
        ];
      }
      {
        name = "Wrapper Modules";
        data = "numbered";
        path = "md/wrapper-modules.md";
        src = ./md/wrapper-modules.md;
        subchapters = map (n: {
          name = n;
          data = "numbered";
          path = "wrapperModules/${n}.md";
          src = "${placeholder "generated"}/wrapper_docs/${n}.md";
        }) (builtins.attrNames config.drv.wrapper_docs);
      }
    ];
  };
}
