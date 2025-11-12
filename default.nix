{
  pkgs ? import <nixpkgs> { },
  nixpkgs ? null,
  # NOTE: if a flake input is added, add it here too.
  # <NAME> ? import (builtins.fetchGit (let
  #     lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.<NAME>.locked;
  #   in {
  #     url = "https://github.com/${lock.owner}/${lock.repo}.git";
  #     rev = lock.rev;
  #   })),
  ...
}@args:
let
  callFlake-less =
    path: inputs:
    let
      bareflake = import "${path}/flake.nix";
      res = bareflake.outputs (
        inputs
        // rec {
          self = res // {
            outputs = res;
            outPath = path;
            inputs = builtins.mapAttrs (
              n: _: (inputs // { inherit self; }).${n} or builtins.throw "Missing input ${n}"
            ) bareflake.inputs;
          };
        }
      );
    in
    res;
in
callFlake-less ./. (
  {
    nixpkgs = if nixpkgs != null then nixpkgs else (pkgs // { outPath = pkgs.path; });
  }
  // (builtins.removeAttrs args [ "pkgs" ])
)
