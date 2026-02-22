{
  pkgs,
  self,
}:

let
  zshWrapped = self.wrappers.zsh.wrap {
    inherit pkgs;
    zshAliases = {
      testAlias = "echo Alias";
    };
    # zdotdir files contain both their own alias and the alias specified in the direct file options
    # below to test override functionality
    zdotdir = ./test-zdotdir;
    zshenv.content = "alias testZshenv=\"echo Zshenv\"";
    zshrc.content = "alias testZshrc=\"echo Zshrc\"";
    zlogin.content = "alias testZlogin=\"echo Zlogin\"";
  };

in
pkgs.runCommand "zsh-test" { } ''
  "${zshWrapped}/bin/zsh" --version | grep -q "${zshWrapped.version}"

  "${zshWrapped}/bin/zsh" -ic testAlias | grep -q "Alias"

  "${zshWrapped}/bin/zsh" -ic testZshenv | grep -q "Zshenv"
  "${zshWrapped}/bin/zsh" -ic testZdotenv | grep -q "Zdot env"

  "${zshWrapped}/bin/zsh" -ic testZshrc | grep -q "Zshrc"
  "${zshWrapped}/bin/zsh" -ic testZdotrc | grep -q "Zdot rc"

  "${zshWrapped}/bin/zsh" -lc testZlogin | grep -q "Zlogin"
  "${zshWrapped}/bin/zsh" -lc testZdotlogin | grep -q "Zdot login"

  touch $out
''
