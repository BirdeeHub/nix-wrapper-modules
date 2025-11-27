{
  lib,
  wrappers_dir ? import ../wrapperModules { inherit lib wlib; },
  modules_dir ? import ../modules { inherit lib wlib; },
  checks ? wrappers_dir.checks or { } // modules_dir.checks or { },
  wrapperModules ? wrappers_dir.wrapperModules or { },
  modules ? modules_dir.modules or { },
  modulesPath ? ../.,
  wlib ? import ./lib.nix {
    inherit
      lib
      wlib
      wrapperModules
      modules
      checks
      modulesPath
      ;
  },
}:
wlib
