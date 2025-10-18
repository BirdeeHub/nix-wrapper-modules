{
  pkgs,
  self,
}:

let
  wrappedPackage = self.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hello;
    args = [
      "--greeting"
      "hi"
      "--verbose"
    ];
  };

in
pkgs.runCommand "args-direct-test" { } ''
  echo "Testing direct args list..."

  wrapperScript="${wrappedPackage}/bin/hello"
  if [ ! -f "$wrapperScript" ]; then
    echo "FAIL: Wrapper script not found"
    exit 1
  fi

  if ! grep -q -- "--greeting" "$wrapperScript"; then
    echo "FAIL: --greeting not found"
    cat "$wrapperScript"
    exit 1
  fi

  if ! grep -q "hi" "$wrapperScript"; then
    echo "FAIL: 'hi' not found"
    cat "$wrapperScript"
    exit 1
  fi

  if ! grep -q -- "--verbose" "$wrapperScript"; then
    echo "FAIL: --verbose not found"
    cat "$wrapperScript"
    exit 1
  fi

  echo "SUCCESS: Direct args test passed"
  touch $out
''
