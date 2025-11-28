{
  pkgs,
  self,
}:

let
  gitWrapped = self.wrapperModules.git.wrap {
    inherit pkgs;
    settings = {
      user = {
        name = "Test User";
        email = "test@example.com";
      };
    };
  };

in
pkgs.runCommand "git-test" { } ''
  "${gitWrapped}/bin/git" config user.name | grep -q "Test User"
  "${gitWrapped}/bin/git" config user.email | grep -q "test@example.com"
  touch $out
''
