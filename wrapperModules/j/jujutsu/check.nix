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
  res=$(${jujutsuWrapped}/bin/jj config list --user)
  if ! echo "$res" | grep -q 'Test User'; then
    echo "failed to list test user!"
    echo "wrapper contents for ${jujutsuWrapped}/bin/jj"
    cat "${jujutsuWrapped}/bin/jj"
    exit 1
  fi
  if ! echo "$res" | grep -q 'test@example.com'; then
    echo "failed to list test email!"
    echo "wrapper contents for ${jujutsuWrapped}/bin/jj"
    cat "${jujutsuWrapped}/bin/jj"
    cat "${jujutsuWrapped.configuration.env.JJ_CONFIG.data}"
    "${jujutsuWrapped}/bin/jj" config list --user
    exit 1
  fi
  touch $out
''
