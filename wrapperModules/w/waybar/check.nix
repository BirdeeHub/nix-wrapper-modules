{
  pkgs,
  self,
}:
let
  waybarWrapped = self.wrappers.waybar.wrap {
    inherit pkgs;

    settings = {
      position = "top";
      modules-left = [ ];
      modules-right = [ ];
      modules-center = [ ];
    };

    "style.css".content = "";
  };

in
if builtins.elem pkgs.stdenv.hostPlatform.system self.wrappers.waybar.meta.platforms then
  pkgs.runCommand "waybar-test" { } ''
    "${waybarWrapped}/bin/waybar" --version | grep -q "${waybarWrapped.version}"
    touch $out
  ''
else
  null
