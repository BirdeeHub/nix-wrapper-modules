{
  pkgs,
  self,
}:

let
  wrappedPackage = self.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hello;
    addFlag = [
      # NOTE: these do not guarantee that the value is strictly next.
      # for that you should group them
      {
        data = "hi";
        after = [ "greeting" ];
      }
      {
        data = "--greeting";
        name = "greeting";
      }
    ];
  };
  wrappedPackage2 = self.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hello;
    addFlag = [
      [
        "--greeting"
        "hi"
      ]
    ];
  };

  mkTest = pkg: /* bash */ ''
    wrapperScript="${pkg}/bin/hello"
    if [ ! -f "$wrapperScript" ]; then
      echo "FAIL: Wrapper script not found"
      exit 1
    fi

    if ! $wrapperScript | grep -q -- "hi"; then
      echo "FAIL: hi not found"
      cat "$wrapperScript"
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
  '';

in
pkgs.runCommand "args-direct-test" { } ''
  echo "Testing direct args list..."

  ${mkTest wrappedPackage}
  ${mkTest wrappedPackage2}

  echo "SUCCESS: Direct args test passed"
  touch $out
''
