{
  pkgs,
  self,
}:

let
  jujutsuWrapped = self.wrapperModules.jujutsu.wrap {
    inherit pkgs;
    settings = {
      user = {
        name = "Test User";
        email = "test@example.com";
      };
    };
  };

in
pkgs.runCommand "jujutsu-test" { } ''
  "${jujutsuWrapped}/bin/jj" config list --user | grep -q 'user.name = "Test User"'
  "${jujutsuWrapped}/bin/jj" config list --user | grep -q 'user.email = "test@example.com"'
  touch $out
''
