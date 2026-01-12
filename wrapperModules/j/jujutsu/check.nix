{
  pkgs,
  self,
}:

let
  jujutsuWrapped = self.wrappedModules.jujutsu.wrap {
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
  if ! "${jujutsuWrapped}/bin/jj" config list --user | grep -q 'Test User'; then
    echo "failed to list test user!"
    echo "wrapper contents for ${jujutsuWrapped}/bin/jj"
    cat "${jujutsuWrapped}/bin/jj"
    exit 1
  fi
  if ! "${jujutsuWrapped}/bin/jj" config list --user | grep -q -F 'test@example.com'; then
    echo "failed to list test email!"
    echo "wrapper contents for ${jujutsuWrapped}/bin/jj"
    cat "${jujutsuWrapped}/bin/jj"
    exit 1
  fi
  touch $out
''
