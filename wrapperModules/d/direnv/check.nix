{
  pkgs,
  self,
}:

let
  direnvWrapped = self.wrappers.direnv.wrap {
    inherit pkgs;
    nix-direnv.enable = true;
  };

  zshWithArgs = zshWrapped.wrap { flags."-ic" = "echo \"$TESTVAR\""; };

in
pkgs.runCommand "direnv-test" { } ''
  "${zshWrapped}/bin/direnv" --version | grep -q "${direnv.version}"

  touch $out
''
