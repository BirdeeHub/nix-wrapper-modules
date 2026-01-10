{
  pkgs,
  self,
}:
let
  waybarWrapped =
    self.wrapperModules.waybar.wrap {
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
pkgs.runCommand "waybar-test" { } ''
  "${waybarWrapped}/bin/waybar" --version | grep -q "${waybarWrapped.version}"
  touch $out
''
