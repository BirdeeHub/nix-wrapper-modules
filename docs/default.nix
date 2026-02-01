{
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
    }:
    name: module:
    pkgs.writeText "${name}-${prefix}-docs" (
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
          inherit includeCore;
          ${if descriptionStartsOpen != null then "descriptionStartsOpen" else null} = descriptionStartsOpen;
          ${if descriptionIncluded != null then "descriptionIncluded" else null} = descriptionIncluded;
          ${if moduleStartsOpen != null then "moduleStartsOpen" else null} = moduleStartsOpen;
        }
      )
    );

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
in
{
  imports = [ wlib.wrapperModules.mdbook ];
  mainBook = "nix-wrapper-modules";
  books.nix-wrapper-modules = {
    book.book = {
      src = "src";
      authors = [ "BirdeeHub" ];
      language = "en";
      title = "nix-wrapper-modules";
      description = "Make wrapper derivations with the module system! Use the existing modules, or write your own!";
    };
    book.output.html.git-repository-url = "https://github.com/BirdeeHub/nix-wrapper-modules";
    book.output.html.redirect =
      lib.pipe
        [
          "alacritty"
          "atool"
          "btop"
          "claude-code"
          "foot"
          "fuzzel"
          "git"
          "helix"
          "jujutsu"
          "mako"
          "mpv"
          "neovim"
          "niri"
          "notmuch"
          "nushell"
          "opencode"
          "ov"
          "rofi"
          "tealdeer"
          "tmux"
          "vim"
          "waybar"
          "wezterm"
          "xplr"
          "yazi"
        ]
        [
          (map (n: {
            name = "/${n}.html";
            value = "wrapperModules/${n}.html";
          }))
          builtins.listToAttrs
          (
            v:
            v
            // {
              "/home.html" = "/md/intro.html";
              "/getting-started.html" = "/md/getting-started.html";
              "/lib-intro.html" = "/md/lib-intro.html";
              "/wlib.html" = "/lib/wlib.html";
              "/types.html" = "/lib/types.html";
              "/dag.html" = "/lib/dag.html";
              "/core.html" = "/lib/core.html";
              "/helper-modules.html" = "/md/helper-modules.html";
              "/wrapper-modules.html" = "/md/wrapper-modules.html";
              "/default.html" = "/modules/default.html";
              "/makeWrapper.html" = "/modules/makeWrapper.html";
              "/symlinkScript.html" = "/modules/symlinkScript.html";
            }
          )
        ];
    summary = [
      {
        data = "title";
        name = "nix-wrapper-modules";
      }
      {
        name = "Intro";
        data = "numbered";
        path = "md/intro.md";
        src = pkgs.runCommand "intro.md" { src = ../README.md; } ''
          sed 's|# \[nix-wrapper-modules\](https://birdeehub.github.io/nix-wrapper-modules/)|# [nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules)|' < "$src" > "$out"
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
            src = pkgs.runCommand "wrapper-lib-docs" { src = ../lib/lib.nix; } ''
              ${pkgs.nixdoc}/bin/nixdoc --category "" --description '`wlib` main set documentation' --file "$src" --prefix "wlib" >> $out
            '';
          }
          {
            name = "types";
            data = "numbered";
            path = "lib/types.md";
            src = pkgs.runCommand "wrapper-types-docs" { src = ../lib/types.nix; } ''
              ${pkgs.nixdoc}/bin/nixdoc --category "types" --description '`wlib.types` set documentation' --file "$src" --prefix "wlib" >> $out
            '';
          }
          {
            name = "dag";
            data = "numbered";
            path = "lib/dag.md";
            src = pkgs.runCommand "wrapper-dag-docs" { src = ../lib/dag.nix; } ''
              ${pkgs.nixdoc}/bin/nixdoc --category "dag" --description '`wlib.dag` set documentation' --file "$src" --prefix "wlib" >> $out
            '';
          }
        ];
      }
      {
        name = "Core Options Set";
        data = "numbered";
        path = "lib/core.md";
        src = buildModuleDocs {
          package = pkgs.hello;
          title = "Core (builtin) Options set";
        } "core" wlib.core;
      }
      {
        name = "`wlib.modules.default`";
        data = "numbered";
        path = "modules/default.md";
        src = module_docs.default;
      }
      {
        name = "Helper Modules";
        data = "numbered";
        path = "md/helper-modules.md";
        src = ./md/helper-modules.md;
        subchapters = lib.mapAttrsToList (n: v: {
          name = n;
          data = "numbered";
          path = "modules/${n}.md";
          src = v;
        }) (removeAttrs module_docs [ "default" ]);
      }
      {
        name = "Wrapper Modules";
        data = "numbered";
        path = "md/wrapper-modules.md";
        src = ./md/wrapper-modules.md;
        subchapters = lib.mapAttrsToList (n: v: {
          name = n;
          data = "numbered";
          path = "wrapperModules/${n}.md";
          src = v;
        }) wrapper_docs;
      }
    ];
  };
}
