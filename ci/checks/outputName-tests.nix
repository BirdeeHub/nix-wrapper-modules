{
  pkgs,
  self,
  ...
}:

let
  inherit (pkgs) runCommand;
  inherit (self.lib) wrapPackage;

  # Test with custom outputName
  wrapped-custom-out = wrapPackage {
    inherit pkgs;
    package = pkgs.hello;
    # NOTE: It should detect that myout is not present and add it
    # outputs = [
    #   "out"
    #   "myout"
    # ];
    outputName = "myout";
  };

  # Test with custom binDir
  wrapped-custom-binDir = wrapPackage {
    inherit pkgs;
    package = pkgs.hello;
    binDir = "sbin";
  };

  # # Test with binDir = null (no subdirectory)
  wrapped-null-binDir = wrapPackage {
    inherit pkgs;
    package = pkgs.hello;
    binDir = null;
  };

in

runCommand "outputName-tests" { } ''
  # Test custom outputName
  if [ ! -f "${wrapped-custom-out.myout}/bin/hello" ]; then
    echo "FAIL: Expected wrapper at ${wrapped-custom-out.myout}/bin/hello"
    echo "Contents of ${wrapped-custom-out.myout}:"
    ls -laR "${wrapped-custom-out.myout}"
    exit 1
  fi

  # Test custom binDir
  if [ ! -f "${wrapped-custom-binDir}/sbin/hello" ]; then
    echo "FAIL: Expected wrapper at ${wrapped-custom-binDir}/sbin/hello"
    echo "Contents of ${wrapped-custom-binDir}:"
    ls -laR "${wrapped-custom-binDir}"
    exit 1
  fi

  # Test binDir = null (no subdirectory)
  echo "Testing binDir = null..."
  if [ ! -f "${wrapped-null-binDir}/hello" ]; then
    echo "FAIL: Expected binary at ${wrapped-null-binDir}/hello"
    echo "Contents of ${wrapped-null-binDir}:"
    ls -la "${wrapped-null-binDir}/"
    exit 1
  fi
  touch $out
''
