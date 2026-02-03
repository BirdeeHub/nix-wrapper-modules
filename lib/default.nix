{
  lib,
  wrappers_dir ? import ../wrapperModules { inherit lib wlib; },
  modules_dir ? import ../modules { inherit lib wlib; },
  checks ? {
    wrapper = wrappers_dir.checks or { };
    helper = modules_dir.checks or { };
  },
  wrapperModules ? wrappers_dir.wrapperModules or { },
  modules ? modules_dir.modules or { },
  maintainers ? import ../maintainers { inherit lib; },
  modulesPath ? toString ../.,
  wlib ? import ./lib.nix {
    inherit
      lib
      wlib
      wrapperModules
      modules
      checks
      modulesPath
      maintainers
      ;
  },
}:
wlib
