{
  pkgs,
  self,
  ...
}:

let
  # Create a dummy package with a desktop file that references itself
  dummyPackage =
    (pkgs.runCommand "dummy-app"
      {
        nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
      }
      ''
        mkdir -p $out/bin
        mkdir -p $out/share/applications

        # Make a dummy program to have a valid package
        makeWrapper ${pkgs.hello}/bin/hello $out/bin/dummy-app

        # Add a secondary binary file that references the package path
        makeWrapper ${pkgs.hello}/bin/hello $out/bin/other-bin \
          --add-flag "--greeting" \
          --add-flag "Hello, $out"

        # Create a desktop file that references the package path
        cat > $out/share/applications/dummy-app.desktop <<EOF
        [Desktop Entry]
        Name=Dummy App
        Exec=$out/bin/dummy-app
        Icon=$out/share/icons/dummy-app.png
        Type=Application
        EOF
      ''
    )
    // {
      meta.mainProgram = "dummy-app";
    };

  # Wrap the package
  wrappedPackage = self.lib.wrapPackage (
    { options, ... }:
    {
      inherit pkgs;

      filesToPatch = options.filesToPatch.default ++ [ "bin/other-bin" ];

      package = dummyPackage;
    }
  );
in
pkgs.runCommand "filesToPatch-test"
  {
    originalPath = "${dummyPackage}";
    wrappedPath = "${wrappedPackage}";
  }
  ''
    echo "Testing filesToPatch functionality..."
    echo "Original package path: $originalPath"
    echo "Wrapped package path: $wrappedPath"

    # Test 1: Check replace in text file (.desktop)
    desktopFile="$wrappedPath/share/applications/dummy-app.desktop"

    if [ ! -f "$desktopFile" ]; then
      echo "FAIL: Desktop file not found at $desktopFile"
      exit 1
    fi

    # The desktop file should NOT contain references to the original package
    if grep -qF "$originalPath" "$desktopFile"; then
      echo "FAIL: Desktop file still contains reference to original package"
      echo "Original path: $originalPath"
      exit 1
    fi

    # The desktop file SHOULD contain references to the wrapped package
    if ! grep -qF "$wrappedPath" "$desktopFile"; then
      echo "FAIL: Desktop file does not contain reference to wrapped package"
      echo "Wrapped path: $wrappedPath"
      exit 1
    fi

    # Test 2: Check replace in binary file
    binaryFile="$wrappedPath/bin/other-bin"

    # The binary file should NOT contain references to the original package
    if grep -qF "$originalPath" "$binaryFile"; then
      echo "FAIL: Binary file still contains reference to original package"
      echo "Original path: $originalPath"
      exit 1
    fi

    # The binary file SHOULD contain references to the original package
    if ! grep -qF "$wrappedPath" "$binaryFile"; then
      echo "FAIL: Binary file does not contain reference to wrapped package"
      echo "Original path: $originalPath"
      exit 1
    fi

    echo "SUCCESS: files properly patched"
    touch $out
  ''
