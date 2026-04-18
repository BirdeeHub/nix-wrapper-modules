{
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
      cfg = wrapper.passthru.configuration;
      dotdir = "${wrapper}/${cfg.configDirname}";
    in
    dotdir;
in
runTests { wrapperModule = self.wrappers.direnv; } [

  (runTest "wrapper should output correct version" (wrapper: ''
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

  (runTest
    {
      name = "if nix-direnv is disabled then lib/nix-direnv.sh should not exist";
      config.nix-direnv.enable = false;
    }
    (wrapper: [
      (isDirectory (getDotdir wrapper))
      (notIsFile "${getDotdir wrapper}/lib/nix-direnv.sh")
    ])
  )

  (runTest
    {
      name = "if mise is enabled then lib/mise.sh should exists";
      config.mise.enable = true;
    }
    (wrapper: [
      (isDirectory (getDotdir wrapper))
      (isFile "${getDotdir wrapper}/lib/mise.sh")
    ])
  )

  (runTest
    {
      name = "if mise is disabled then lib/mise.sh should not exist";
      config.mise.enable = false;
    }
    (wrapper: [
      (isDirectory (getDotdir wrapper))
      (notIsFile "${getDotdir wrapper}/lib/mise.sh")
    ])
  )

  (runTest
    {
      name = "if a lib-script is set then it should be generated";
      config.lib."foo.sh" = "echo foo";
    }
    (
      { wrapper, config }:
      let
        dotdir = getDotdir wrapper;
        libScriptFile = dotdir + "/lib/foo.sh";
      in
      [
        (isDirectory dotdir)
        (isFile libScriptFile)
        (fileContains libScriptFile config.lib."foo.sh")
      ]
    )
  )

  (runTest
    {
      name = "if silent mode is enabled then log settings should be set";
      config.silent = true;
    }
    (
      wrapper:
      let
        dotdir = getDotdir wrapper;
        direnvTomlFile = dotdir + "/direnv.toml";
      in
      [
        (isDirectory dotdir)
        (isFile direnvTomlFile)
        (fileContains direnvTomlFile "log_format")
        (fileContains direnvTomlFile "log_filter")
      ]
    )
  )

  (runTest
    {
      name = "if extraConfig is working";
      config.extraConfig.fooSection.fooKey = "fooValue;";
    }
    (
      wrapper:
      let
        dotdir = getDotdir wrapper;
        direnvTomlFile = dotdir + "/direnv.toml";
      in
      [
        (isDirectory dotdir)
        (isFile direnvTomlFile)
        (fileContains direnvTomlFile "\\[fooSection\\]")
        (fileContains direnvTomlFile "fooKey.*fooValue")
      ]
    )
  )

  (runTest
    {
      name = "if direnvrc is working";
      config.direnvrc = "echo foo";
    }
    (
      { wrapper, config }:
      let
        dotdir = getDotdir wrapper;
        direnvrcFile = dotdir + "/direnvrc";
      in
      [
        (isDirectory dotdir)
        (isFile direnvrcFile)
        (fileContains direnvrcFile config.direnvrc)
      ]
    )
  )
]
