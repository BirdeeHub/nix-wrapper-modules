{ lib, wlib }:
rec {
  collectOptions = import ./collectOptions.nix lib;
  normWrapperDocs = import ./normopts.nix { inherit lib collectOptions; };
  wrapperModuleMD = import ./rendermd.nix { inherit wlib lib normWrapperDocs; };
}
