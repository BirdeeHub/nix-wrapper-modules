{
  pkgs,
  self,
}:

let
  nushellWrapped =
    (self.wrapperModules.nushell.apply {
      inherit pkgs;
    }).wrapper;

in
pkgs.runCommand "nushell-test" { } ''
  "${nushellWrapped}/bin/nu" --version | grep -q "${nushellWrapped.version}"
  touch $out
''
