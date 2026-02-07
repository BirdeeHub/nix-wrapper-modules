{
  pkgs,
  self,
}:

let
  zshWrapped = self.wrappers.zsh.wrap {
    inherit pkgs;
    zdotdir = ./test-zdotdir;
    zdotFiles.zshrc.content = "alias test-zdot=\"echo Test Fail\"";
  };
  zshFilesWrapped = self.wrappers.zsh.wrap {
    inherit pkgs;
    zdotFiles.zshrc.content = "alias test-zdot=\"echo Test Success\"";
  };

in
pkgs.runCommand "zsh-test" { } ''
  "${zshWrapped}/bin/zsh" --version | grep -q "${zshWrapped.version}"
  "${zshWrapped}/bin/zsh" -c "echo \$ZDOTDIR" | grep -q "test-zdotdir"
  "${zshWrapped}/bin/zsh" -c "ls \$ZDOTDIR"
  "${zshWrapped}/bin/zsh" -ic testZdot | grep -q "Testing Success"
  touch $out
''
