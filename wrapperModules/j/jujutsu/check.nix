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
null
/*
  TODO: determine what about this test makes it flaky in actions.
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
      cat "${jujutsuWrapped.configuration.env.JJ_CONFIG.data}"
      "${jujutsuWrapped}/bin/jj" config list --user
      exit 1
    fi
    touch $out
  ''
*/
