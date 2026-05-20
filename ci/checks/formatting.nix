{
  pkgs,
  self,
  ...
}:

pkgs.runCommand "formatting-check" { } ''
  find ${../../.} -name "*.nix" -print0 | xargs -0 ${pkgs.lib.getExe pkgs.nixfmt} --check
  touch $out
''
