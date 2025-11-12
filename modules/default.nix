{ lib, wlib, ... }:
let
  callDirs =
    {
      lib,
      wlib,
      dirname,
      dirpath,
      ...
    }@args:
    let
      filterImportDir =
        cond:
        (
          name: type:
          (if cond != null then cond name type else true)
          && type == "directory"
          && (
            if dirname == "other" then builtins.match "^[A-Za-z].*" name == null else lib.hasPrefix dirname name
          )
        );
    in
    {
      wrapperModules = lib.pipe dirpath [
        builtins.readDir
        (lib.filterAttrs (filterImportDir null))
        (builtins.mapAttrs (name: _: dirpath + "/${name}/module.nix"))
      ];
      checks = lib.pipe dirpath [
        builtins.readDir
        (lib.filterAttrs (filterImportDir (n: _: builtins.pathExists (dirpath + "/${n}/check.nix"))))
        (builtins.mapAttrs (name: _: dirpath + "/${name}/check.nix"))
      ];
    };
in
lib.pipe ./. [
  builtins.readDir
  (lib.filterAttrs (_: type: type == "directory"))
  (builtins.mapAttrs (
    name: _:
    import ./${name} {
      inherit lib wlib callDirs;
      dirname = name;
      dirpath = ./${name};
    }
  ))
  builtins.attrValues
  (builtins.foldl' lib.recursiveUpdate { })
]
