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
      "--verbose" = { };
    };
    flagSeparator = "=";
  };

in
pkgs.runCommand "flags-equals-separator-test" { } ''
  echo "Testing flags with equals separator..."

  wrapperScript="${wrappedPackage}/bin/hello"
  if [ ! -f "$wrapperScript" ]; then
    echo "FAIL: Wrapper script not found"
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
