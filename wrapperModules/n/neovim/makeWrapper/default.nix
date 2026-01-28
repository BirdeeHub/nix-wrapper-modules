{
  config,
  callPackage,
  lib,
  wlib,
  luajit,
  ...
}@args:
let
  maybe_compile = "${lib.optionalString (config.settings.compile_generated_lua or false != false)
    "| ${config.package.lua or luajit}/bin/lua -e 'local src=io.read([[*a]]); local f,err=load(src); if not f then error(err) end; io.write(string.dump(f${
      lib.optionalString (config.settings.compile_generated_lua or false != "debug") ", true"
    }))' "
  }";
  wrapNvim = callPackage (
    if config.wrapperImplementation or "nix" == "nix" then
      (import ./makeWrapperNix.nix maybe_compile)
    else
      (import ./makeWrapper.nix maybe_compile)
  ) args;
in
wrapNvim
+ "\n"
+ (import wlib.modules.makeWrapper).wrapVariants { inherit config wlib callPackage; }
