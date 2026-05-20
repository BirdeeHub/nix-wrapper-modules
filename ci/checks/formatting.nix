{
  pkgs,
  self,
  ...
}:

pkgs.runCommand "formatting-check" { } ''
  find ${../../.} -type f -name "*.nix" -exec ${pkgs.lib.getExe pkgs.nixfmt} --check {} +
  touch $out
''
