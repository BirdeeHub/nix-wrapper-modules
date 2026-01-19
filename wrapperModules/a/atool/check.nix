{ pkgs, self }:
let
  atoolWrapped = self.wrappedModules.atool.wrap {
    inherit pkgs;
    tools.enable = true;
    tools.paths.zip = "${pkgs.zip}/bin/zip";
    tools.paths.unzip = "${pkgs.unzip}/bin/unzip";
    tools.paths.tar = "${pkgs.gnutar}/bin/tar";
  };
in
pkgs.runCommand "atool-test" { } ''
  mkdir -p $out
  # Unfortunately --junk-paths can't be passed to zip via format-option because
  # format-option is only used for the 7z format; possibly an upstream oversight?
  # Regardless, to get relative paths, I just change directory instead.
  cd $out
  echo 'hello world' > testfile

  "${atoolWrapped}/bin/apack" --explain archive.zip testfile 2>&1 >/dev/null | grep "${pkgs.zip}/bin/zip -r archive.zip testfile"
  "${atoolWrapped}/bin/als" --explain archive.zip 2>&1 >/dev/null | grep "${pkgs.unzip}/bin/unzip -l archive.zip"
  "${atoolWrapped}/bin/acat" --explain archive.zip testfile 2>&1 >/dev/null | grep "${pkgs.unzip}/bin/unzip -p archive.zip testfile"
  "${atoolWrapped}/bin/arepack" archive.zip archive.tar.gz
  "${atoolWrapped}/bin/aunpack" --explain archive.tar.gz 2>&1 >/dev/null | grep "${pkgs.gnutar}/bin/tar xvzf archive.tar.gz"
''
