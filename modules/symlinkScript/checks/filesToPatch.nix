{
  pkgs,
  self,
}:

let
  # Create a dummy package with a desktop file that references itself
  dummyPackage =
    (pkgs.runCommand "dummy-app" { } ''
      mkdir -p $out/bin
      mkdir -p $out/share/applications

      # Create a simple executable
      cat > $out/bin/dummy-app <<'EOF'
      #!/bin/sh
      echo "Hello from dummy app"
      EOF
      chmod +x $out/bin/dummy-app

      # Create a desktop file that references the package path
      cat > $out/share/applications/dummy-app.desktop <<EOF
      [Desktop Entry]
      Name=Dummy App
      Exec=$out/bin/dummy-app
      Icon=$out/share/icons/dummy-app.png
      Type=Application
      EOF
    '')
    // {
      meta.mainProgram = "dummy-app";
    };

  # Wrap the package
  wrappedPackage = self.lib.wrapPackage {
    inherit pkgs;
    package = dummyPackage;
  };

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

    # Read the desktop file
    desktopFile="${wrappedPackage}/share/applications/dummy-app.desktop"

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

    echo "SUCCESS: Desktop file was properly patched"
    touch $out
  ''
