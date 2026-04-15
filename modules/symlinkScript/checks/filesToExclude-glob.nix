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
      mkdir -p $out/share/doc

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

      cat > $out/bin/debug-tool <<'EOF'
      #!/bin/sh
      echo "Debug tool"
      EOF
      chmod +x $out/bin/debug-tool

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

      cat > $out/share/applications/debug.desktop <<EOF
      [Desktop Entry]
      Name=Debug
      Exec=debug-tool
      Type=Application
      EOF

      # Create doc files
      echo "README" > $out/share/doc/README
      echo "CHANGELOG" > $out/share/doc/CHANGELOG
    '')
    // {
      meta.mainProgram = "main-app";
    };

  # Test glob patterns
  wrappedPackage = self.lib.wrapPackage {
    inherit pkgs;
    package = multiAppPackage;
    filesToExclude = [
      "bin/*-tool" # Exclude all files ending with -tool
      "share/doc/*" # Exclude all documentation files
    ];
  };

in
pkgs.runCommand "filesToExclude-glob-test" { } ''
  echo "Testing filesToExclude with glob patterns..."

  # Check that files matching glob patterns are NOT present
  if [ -f "${wrappedPackage}/bin/helper-tool" ]; then
    echo "FAIL: bin/helper-tool should be excluded by bin/*-tool glob"
    exit 1
  fi

  if [ -f "${wrappedPackage}/bin/debug-tool" ]; then
    echo "FAIL: bin/debug-tool should be excluded by bin/*-tool glob"
    exit 1
  fi

  if [ -f "${wrappedPackage}/share/doc/README" ]; then
    echo "FAIL: share/doc/README should be excluded by share/doc/* glob"
    exit 1
  fi

  if [ -f "${wrappedPackage}/share/doc/CHANGELOG" ]; then
    echo "FAIL: share/doc/CHANGELOG should be excluded by share/doc/* glob"
    exit 1
  fi

  # Check that non-matching files ARE present
  if [ ! -f "${wrappedPackage}/bin/main-app" ]; then
    echo "FAIL: bin/main-app should be present"
    exit 1
  fi

  if [ ! -f "${wrappedPackage}/bin/legacy-app" ]; then
    echo "FAIL: bin/legacy-app should be present"
    exit 1
  fi

  if [ ! -f "${wrappedPackage}/share/applications/main-app.desktop" ]; then
    echo "FAIL: share/applications/main-app.desktop should be present"
    exit 1
  fi

  # Desktop files for tools should still be there (only bin/*-tool was excluded)
  if [ ! -f "${wrappedPackage}/share/applications/helper.desktop" ]; then
    echo "FAIL: share/applications/helper.desktop should be present"
    exit 1
  fi

  if [ ! -f "${wrappedPackage}/share/applications/debug.desktop" ]; then
    echo "FAIL: share/applications/debug.desktop should be present"
    exit 1
  fi

  # Verify the binaries still work
  if ! "${wrappedPackage}/bin/main-app" > /dev/null; then
    echo "FAIL: main-app is not executable"
    exit 1
  fi

  if ! "${wrappedPackage}/bin/legacy-app" > /dev/null; then
    echo "FAIL: legacy-app is not executable"
    exit 1
  fi

  echo "SUCCESS: filesToExclude glob test passed"
  touch $out
''
