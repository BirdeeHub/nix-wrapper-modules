{
  pkgs,
  self,
}:

let
  makoWrapped =
    (self.wrappedModules.mako.apply {
      inherit pkgs;
      settings.icon-location = "left";
    }).wrapper;

in
if builtins.elem pkgs.stdenv.hostPlatform.system self.wrappedModules.mako.meta.platforms then
  pkgs.runCommand "mako-test" { } ''
    "${makoWrapped}/bin/mako" --help | grep -q "mako"
    grep -q --no-ignore-case -- "--config" "${makoWrapped}/bin/mako"
    touch $out
  ''
else
  null
