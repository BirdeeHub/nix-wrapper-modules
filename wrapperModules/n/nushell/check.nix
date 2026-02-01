{
  pkgs,
  self,
}:
let
  nushellWrapped = self.wrappers.nushell.wrap {
    inherit pkgs;
  };

in
pkgs.runCommand "nushell-test" { } ''
  "${nushellWrapped}/bin/nu" --version | grep -q "${nushellWrapped.version}"
  touch $out
''
