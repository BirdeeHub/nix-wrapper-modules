{
  pkgs,
  self,
}:

let
  helixWrapped =
    (self.wrapperModules.helix.apply {
      inherit pkgs;
    }).wrapper;

in
pkgs.runCommand "helix-test" { } ''
  # if the config is invalid the text helix will complain here.
  # sady no other dedicated check config command exists
  res=$("${helixWrapped}/bin/hx" --health | grep "malformed" || true)
  echo $res
  if [[ ''${#res} == 0 ]]; then
    touch $out
  fi
''
