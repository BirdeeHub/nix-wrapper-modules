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
      "--debug" = false;
      "--trace" = null;
      "--output" = "file.txt";
    };
    flagSeparator = " ";
  };

in
pkgs.runCommand "flags-null-false-test" { } ''
  echo "Testing that false and null flags are omitted..."

  wrapperScript="${wrappedPackage}/bin/hello"
  if [ ! -f "$wrapperScript" ]; then
    echo "FAIL: Wrapper script not found"
    exit 1
  fi

  # Check that included flags are present
  if ! grep -q -- "--greeting" "$wrapperScript"; then
    echo "FAIL: --greeting flag not found"
    cat "$wrapperScript"
    exit 1
  fi

  if ! grep -q "hi" "$wrapperScript"; then
    echo "FAIL: 'hi' not found"
    cat "$wrapperScript"
    exit 1
  fi

  if ! grep -q -- "--verbose" "$wrapperScript"; then
    echo "FAIL: --verbose flag not found"
    cat "$wrapperScript"
    exit 1
  fi

  if ! grep -q -- "--output" "$wrapperScript"; then
    echo "FAIL: --output flag not found"
    cat "$wrapperScript"
    exit 1
  fi

  if ! grep -q "file.txt" "$wrapperScript"; then
    echo "FAIL: 'file.txt' not found"
    cat "$wrapperScript"
    exit 1
  fi

  # Check that false and null flags are NOT present
  if grep -q -- "--debug" "$wrapperScript"; then
    echo "FAIL: --debug flag should be omitted (value was false)"
    cat "$wrapperScript"
    exit 1
  fi

  if grep -q -- "--trace" "$wrapperScript"; then
    echo "FAIL: --trace flag should be omitted (value was null)"
    cat "$wrapperScript"
    exit 1
  fi

  echo "SUCCESS: false and null flags correctly omitted"
  touch $out
''
