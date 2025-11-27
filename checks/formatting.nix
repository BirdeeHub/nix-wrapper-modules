{
  pkgs,
  self,
}:

pkgs.runCommand "formatting-check" { } ''
  ${
    pkgs.lib.getExe self.formatter.${pkgs.stdenv.hostPlatform.system}
  } --no-cache --fail-on-change ${../.}
  touch $out
''
