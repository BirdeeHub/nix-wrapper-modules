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
    makeWrapper = ./makeWrapper.nix;
    makeWrapperNix = ./makeWrapperNix.nix;
    makeWrapperBase = ./makeWrapperBase.nix;
  };
}
