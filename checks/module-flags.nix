{
  pkgs,
  self,
}:

let
  helloModule = self.lib.wrapModule (
    { config, ... }:
    {
      config.package = config.pkgs.hello;
      config.flags = {
        "--greeting" = "world";
        "--silent" = { };
      };
    }
  );

  wrappedPackage = helloModule.apply { inherit pkgs; };

in
pkgs.runCommand "module-flags-test" { } ''
  echo "Testing wrapModule with flags..."

  wrapperScript="${wrappedPackage}/bin/hello"
  if [ ! -f "$wrapperScript" ]; then
    echo "FAIL: Wrapper script not found"
    exit 1
  fi

  # wrapModule uses space separator by default
  if ! grep -q -- "--greeting" "$wrapperScript"; then
    echo "FAIL: --greeting not found"
    cat "$wrapperScript"
    exit 1
  fi

  if ! grep -q "world" "$wrapperScript"; then
    echo "FAIL: 'world' not found"
    cat "$wrapperScript"
    exit 1
  fi

  if ! grep -q -- "--silent" "$wrapperScript"; then
    echo "FAIL: --silent not found"
    cat "$wrapperScript"
    exit 1
  fi

  echo "SUCCESS: wrapModule test passed"
  touch $out
''
