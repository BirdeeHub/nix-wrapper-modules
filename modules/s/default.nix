{
  callDirs,
  dirname,
  wlib,
  lib,
  dirpath,
  ...
}@args:
(callDirs args)
// {
  modules = {
    symlinkScript = ./symlinkScript.nix;
  };
}
