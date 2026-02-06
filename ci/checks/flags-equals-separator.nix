{
  pkgs,
  self,
}:

let
  wrappedPackage = self.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hello;
    flags = {
      "--greeting" = "hi";
      "--verbose" = pkgs.lib.mkDefault true;
    };
    flagSeparator = "=";
  };

  # sanity check binary and shell versions
  binaryImpl = wrappedPackage.wrap {
    wrapperImplementation = "binary";
    flags."--verbose".data = false;
  };
  shellImpl = binaryImpl.wrap {
    wrapperImplementation = pkgs.lib.mkForce "shell";
  };

in
pkgs.runCommand "flags-equals-separator-test" { } ''
  echo "Testing flags with equals separator..."

  wrapperScript="${wrappedPackage}/bin/hello"
  if [ ! -f "$wrapperScript" ]; then
    echo "FAIL: Wrapper script not found"
    exit 1
  fi

  if ! ${binaryImpl}/bin/hello | grep -q -- "hi"; then
    echo "FAIL: the pkgs.makeBinaryWrapper implementation does not greet us!"
    exit 1
  fi
  if ! ${shellImpl}/bin/hello | grep -q -- "hi"; then
    echo "FAIL: the pkgs.makeWrapper implementation does not greet us!"
    exit 1
  fi

  # Check that flags with equals separator are formatted correctly
  # Should have --greeting=hi as a single argument
  if ! grep -q -- "--greeting=hi" "$wrapperScript"; then
    echo "FAIL: --greeting=hi flag not found"
    cat "$wrapperScript"
    exit 1
  fi

  if ! grep -q -- "--verbose" "$wrapperScript"; then
    echo "FAIL: --verbose flag not found"
    cat "$wrapperScript"
    exit 1
  fi

  echo "SUCCESS: Equals separator test passed"
  touch $out
''
