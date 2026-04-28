{
  pkgs,
  self,
}:
let
  fishWrapped = self.wrappers.fish.wrap {
    inherit pkgs;
    configFile.content = "echo \"hello world\"";
  };
in
if builtins.elem pkgs.stdenv.hostPlatform.system self.wrappers.fish.meta.platforms then
  pkgs.runCommand "fish-test" { } ''
    "${fishWrapped}/bin/fish" --version | grep -q "${fishWrapped.version}"
    touch $out
  ''
else
  null
