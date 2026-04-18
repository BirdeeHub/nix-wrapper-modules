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
runTests { wrapperModule = self.wrappers.direnv; } [
  (runTest { blubb = "wrapper should output correct version"; } (wrapper: ''
    "${wrapper}/bin/direnv" --version | grep -q "${wrapper.version}"
  ''))
  (runTest
    {
      name = "if nix-direnv is enabled then lib/nix-direnv.sh should exists";
      config.nix-direnv.enable = true;
    }
    (wrapper: [
      (isDirectory (getDotdir wrapper))
      (isFile "${getDotdir wrapper}/lib/nix-direnv.sh")
    ])
  )
  # (runTest "if nix-direnv is disabled then lib/nix-direnv.sh should not exist"
  #   { nix-direnv.enable = false; }
  #   (wrapper: [
  #     (isDirectory (getDotdir wrapper))
  #     (notIsFile "${getDotdir wrapper}/lib/nix-direnv.sh")
  #   ])
  # )
  # (runTest "if mise is enabled then lib/mise.sh should exists" { mise.enable = true; } (wrapper: [
  #   (isDirectory (getDotdir wrapper))
  #   (isFile "${getDotdir wrapper}/lib/mise.sh")
  # ]))
  # (runTest "if mise is disabled then lib/mise.sh should not exist" { mise.enable = false; }
  #   (wrapper: [
  #     (isDirectory (getDotdir wrapper))
  #     (notIsFile "${getDotdir wrapper}/lib/mise.sh")
  #   ])
  # )
  # (
  #   let
  #     libScriptContent = "echo foo";
  #   in
  #   (runTest "if a lib-script is set then it should be generated" { lib."foo.sh" = libScriptContent; } (
  #     wrapper:
  #     let
  #       libScriptFile = "${getDotdir wrapper}/lib/foo.sh";
  #     in
  #     [
  #       (isDirectory (getDotdir wrapper))
  #       (isFile libScriptFile)
  #       (fileContains libScriptFile libScriptContent)
  #
  #     ]
  #   ))
  # )
  # (runTest "if silent mode is enabled then log settings should be set" { silent = true; } (
  #   wrapper:
  #   let
  #     direnvTomlFile = "${getDotdir wrapper}/direnv.toml";
  #   in
  #   [
  #     (isDirectory (getDotdir wrapper))
  #     (isFile direnvTomlFile)
  #     (fileContains direnvTomlFile "log_format")
  #     (fileContains direnvTomlFile "log_filter")
  #   ]
  # ))
  # (runTest "if extraConfig is working"
  #   {
  #     extraConfig = {
  #       fooSection.fooKey = "fooValue";
  #     };
  #   }
  #   (
  #     wrapper:
  #     let
  #       direnvTomlFile = "${getDotdir wrapper}/direnv.toml";
  #     in
  #     [
  #       (isDirectory (getDotdir wrapper))
  #       (isFile direnvTomlFile)
  #       (fileContains direnvTomlFile "\\[fooSection\\]")
  #       (fileContains direnvTomlFile "fooKey.*fooValue")
  #     ]
  #   )
  # )
  # (
  #   let
  #     direnvrcContent = "echo foo";
  #   in
  #   (runTest "if direnvrc is working" { direnvrc = direnvrcContent; } (
  #     wrapper:
  #     let
  #       direnvrcFile = "${getDotdir wrapper}/direnvrc";
  #     in
  #     [
  #       (isDirectory (getDotdir wrapper))
  #       (isFile direnvrcFile)
  #       (fileContains direnvrcFile direnvrcContent)
  #     ]
  #   ))
  # )
]
