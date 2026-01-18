{ config, callPackage, ... }@args:
callPackage (
  if config.wrapperImplementation or "nix" == "nix" then ./makeWrapperNix.nix else ./makeWrapper.nix
) args
