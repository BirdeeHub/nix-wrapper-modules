{
  pkgs,
  self,
}:

let
  wrappedWithSpaceSep = self.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hello;
    flags = {
      "--include" = [
        "file1.txt"
        "file2.txt"
        "file3.txt"
      ];
      "--verbose" = { };
    };
    flagSeparator = " ";
  };

  wrappedWithEqualsSep = self.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hello;
    flags = {
      "--define" = [
        "VAR1=value1"
        "VAR2=value2"
      ];
    };
    flagSeparator = "=";
  };

in
pkgs.runCommand "flags-list-test" { } ''
  echo "Testing list-valued flags..."

  # Test 1: Space separator with list
  wrapperScript1="${wrappedWithSpaceSep}/bin/hello"
  if [ ! -f "$wrapperScript1" ]; then
    echo "FAIL: Wrapper script 1 not found"
    exit 1
  fi

  # Each list item should generate --include <value> pairs
  if ! grep -q -- "--include" "$wrapperScript1"; then
    echo "FAIL: --include flag not found"
    cat "$wrapperScript1"
    exit 1
  fi

  if ! grep -q "file1.txt" "$wrapperScript1"; then
    echo "FAIL: file1.txt not found"
    cat "$wrapperScript1"
    exit 1
  fi

  if ! grep -q "file2.txt" "$wrapperScript1"; then
    echo "FAIL: file2.txt not found"
    cat "$wrapperScript1"
    exit 1
  fi

  if ! grep -q "file3.txt" "$wrapperScript1"; then
    echo "FAIL: file3.txt not found"
    cat "$wrapperScript1"
    exit 1
  fi

  echo "SUCCESS: Space separator with list test passed"

  # Test 2: Equals separator with list
  wrapperScript2="${wrappedWithEqualsSep}/bin/hello"
  if [ ! -f "$wrapperScript2" ]; then
    echo "FAIL: Wrapper script 2 not found"
    exit 1
  fi

  # Each list item should generate --define=<value> entries
  if ! grep -q -- "--define=VAR1=value1" "$wrapperScript2"; then
    echo "FAIL: --define=VAR1=value1 not found"
    cat "$wrapperScript2"
    exit 1
  fi

  if ! grep -q -- "--define=VAR2=value2" "$wrapperScript2"; then
    echo "FAIL: --define=VAR2=value2 not found"
    cat "$wrapperScript2"
    exit 1
  fi

  echo "SUCCESS: Equals separator with list test passed"
  echo "All list-valued flags tests passed!"
  touch $out
''
