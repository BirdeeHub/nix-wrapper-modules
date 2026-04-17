{
  pkgs,
  self,
  tlib,
  ...
}:

let
  inherit (tlib)
    fileContains
    isDirectory
    isFile
    notIsFile
    runTest
    runTests
    ;
  getDotdir =
    wrapper:
    let
      cfg = (wrapper.eval { }).config;
      dotdir = "${wrapper}/${cfg.configDirname}";
    in
    dotdir;
in
runTests self.wrappers.direnv [
  (runTest "if nix-direnv is enabled then lib/nix-direnv.sh should exists" 
    { nix-direnv.enable = true; } (wrapper: [
      (isDirectory (getDotdir wrapper))
      (isFile "${getDotdir wrapper}/lib/nix-direnv.sh")
    ])
  )
]
