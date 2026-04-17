{
  pkgs,
  self,
}:

let
  # Create a dummy package with multiple binaries and other files
  multiAppPackage =
    (pkgs.runCommand "multi-app" { } ''
      mkdir -p $out/bin
      mkdir -p $out/share/applications

      # Create multiple executables
      cat > $out/bin/main-app <<'EOF'
      #!/bin/sh
      echo "Main app"
      EOF
      chmod +x $out/bin/main-app

      cat > $out/bin/helper-tool <<'EOF'
      #!/bin/sh
      echo "Helper tool"
      EOF
      chmod +x $out/bin/helper-tool

      cat > $out/bin/legacy-app <<'EOF'
      #!/bin/sh
      echo "Legacy app"
      EOF
      chmod +x $out/bin/legacy-app

      # Create desktop files
      cat > $out/share/applications/main-app.desktop <<EOF
      [Desktop Entry]
      Name=Main App
      Exec=main-app
      Type=Application
      EOF

      cat > $out/share/applications/helper.desktop <<EOF
      [Desktop Entry]
      Name=Helper
      Exec=helper-tool
      Type=Application
      EOF
    '')
    // {
      meta.mainProgram = "main-app";
    };

  # Test module interface usage
  testModule = self.lib.wrapModule {
    package = multiAppPackage;
    filesToExclude = [
      "bin/helper-tool"
      "bin/legacy-app"
      "share/applications/helper.desktop"
    ];
  };

  wrappedPackage = (testModule.apply { inherit pkgs; }).wrapper;

in
pkgs.runCommand "module-filesToExclude-test" { } ''
  echo "Testing filesToExclude in module interface..."

  # Check that excluded files are NOT present
  if [ -f "${wrappedPackage}/bin/helper-tool" ]; then
    echo "FAIL: bin/helper-tool should be excluded but is present"
    exit 1
  fi

  if [ -f "${wrappedPackage}/bin/legacy-app" ]; then
    echo "FAIL: bin/legacy-app should be excluded but is present"
    exit 1
  fi

  if [ -f "${wrappedPackage}/share/applications/helper.desktop" ]; then
    echo "FAIL: share/applications/helper.desktop should be excluded but is present"
    exit 1
  fi

  # Check that non-excluded files ARE present
  if [ ! -f "${wrappedPackage}/bin/main-app" ]; then
    echo "FAIL: bin/main-app should be present but is missing"
    exit 1
  fi

  if [ ! -f "${wrappedPackage}/share/applications/main-app.desktop" ]; then
    echo "FAIL: share/applications/main-app.desktop should be present but is missing"
    exit 1
  fi

  # Verify the binary still works
  if ! "${wrappedPackage}/bin/main-app" > /dev/null; then
    echo "FAIL: main-app is not executable"
    exit 1
  fi

  echo "SUCCESS: module filesToExclude test passed"
  touch $out
''
