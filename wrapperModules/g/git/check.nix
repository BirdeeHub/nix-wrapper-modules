{
  pkgs,
  self,
  tlib,
  ...
}:
let
  gitWrapped = self.wrappers.git.wrap {
    inherit pkgs;
    settings = {
      user = {
        name = "Test User";
        email = "test@example.com";
      };
    };
  };
  inherit (tlib) test;
in
tlib.enableBySystem self.wrappers.git (
  tlib.mkTestDrv "git-test" [
    (test "has test user" ''"${gitWrapped}/bin/git" config user.name | grep -q "Test User"'')
    (test "has test email" ''"${gitWrapped}/bin/git" config user.email | grep -q "test@example.com"'')
  ]
)
