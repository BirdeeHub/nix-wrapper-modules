{
  pkgs,
  self,
  ...
}:

let
  wrappedPackage = self.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hello;
    env.MY_NULL_ENV = null;
    envDefault.MY_NULL_DEFAULT = null;
  };

in
pkgs.runCommand "env-null-test" { } ''
  echo "Testing that null env and envDefault entries are omitted..."

  wrapperScript="${wrappedPackage}/bin/hello"
  if [ ! -f "$wrapperScript" ]; then
    echo "FAIL: Wrapper script not found"
    exit 1
  fi

  if grep -q "MY_NULL_ENV" "$wrapperScript"; then
    echo "FAIL: MY_NULL_ENV should be omitted (value was null)"
    cat "$wrapperScript"
    exit 1
  fi

  if grep -q "MY_NULL_DEFAULT" "$wrapperScript"; then
    echo "FAIL: MY_NULL_DEFAULT should be omitted (value was null)"
    cat "$wrapperScript"
    exit 1
  fi

  echo "SUCCESS: null env and envDefault entries correctly omitted"
  touch $out
''
