variant:
{
  config,
  lib,
  wlib,
  callPackage,
  ...
}@args:
let
  call =
    v:
    callPackage
      (if config.wrapperImplementation or "nix" == "nix" then ./makeWrapperNix.nix else ./makeWrapper.nix)
      (
        v
        // {
          ${if builtins.isAttrs wlib then null else "wlib"} = import ../../lib {
            inherit lib;
          };
        }
      );
in
if variant == null || variant == true then
  lib.pipe (config.wrapperVariants or { }) [
    (lib.mapAttrsToList (n: v: if v.enable or false then call (args // { config = v; }) else null))
    (builtins.filter (v: v != null))
    (list: (if variant != true then [ (call args) ] else [ ]) ++ list)
    (builtins.concatStringsSep "\n")
  ]
else if variant == false then
  call args
else if builtins.isString variant then
  if config.wrapperVariants.${variant}.enable or false then
    call (args // { config = config.wrapperVariants.${variant}; })
  else
    ""
else
  ""
