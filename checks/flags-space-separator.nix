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
    flagSeparator = " ";
  };

in
pkgs.runCommand "flags-space-separator-test" { } ''
  echo "Testing flags with space separator..."

  wrapperScript="${wrappedPackage}/bin/hello"
  if [ ! -f "$wrapperScript" ]; then
    echo "FAIL: Wrapper script not found"
    exit 1
  fi

  # Check that flags with space separator are formatted correctly
  # Should have --greeting and hi as separate arguments
  if ! grep -q -- "--greeting" "$wrapperScript"; then
    echo "FAIL: --greeting flag not found"
    cat "$wrapperScript"
    exit 1
  fi

  if ! grep -q "hi" "$wrapperScript"; then
    echo "FAIL: 'hi' argument not found"
    cat "$wrapperScript"
    exit 1
  fi

  if ! grep -q -- "--verbose" "$wrapperScript"; then
    echo "FAIL: --verbose flag not found"
    cat "$wrapperScript"
    exit 1
  fi

  echo "SUCCESS: Space separator test passed"
  touch $out
''
