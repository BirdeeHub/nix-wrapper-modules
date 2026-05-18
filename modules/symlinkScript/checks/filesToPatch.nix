{
  self,
  pkgs,
  tlib,
  ...
}:

let
  inherit (tlib) isFile fileContains test;
in
test "filesToPatch-test" {
  regular =
    let
      wrappedPackage = self.lib.wrapPackage {
        inherit pkgs;
        # Create a dummy package with a desktop file that references itself
        package =
          (pkgs.runCommand "dummy-app" { } ''
            mkdir -p $out/bin
            mkdir -p $out/share/applications

            cat > $out/bin/dummy-app <<'EOF'
            #!/bin/sh
            echo "Hello from dummy app"
            EOF
            chmod +x $out/bin/dummy-app

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
      };
      originalPath = "${wrappedPackage.configuration.package}";
      wrappedPath = "${wrappedPackage}";
      desktopFile = "${wrappedPackage}/share/applications/dummy-app.desktop";
    in
    {
      desktopFileExists = isFile desktopFile;
      noOriginalReferences = {
        cond = "! grep -qF '${originalPath}' '${desktopFile}' ";
        msg = "Desktop file still contains reference to original package. Original path: ${originalPath}";
      };
      containsWrappedReferences = fileContains desktopFile wrappedPath;
    };
  binary =
    let
      wrappedPackage = self.lib.wrapPackage [
        { inherit pkgs; }
        (
          { wlib, pkgs, ... }:
          {
            filesToPatch = [ "bin/fileToBePatched" ];
            package = wlib.wrapPackage [
              { inherit pkgs; }
              (
                { pkgs, ... }:
                {
                  package = pkgs.hello;
                  wrapperImplementation = "binary";
                  wrapperVariants.fileToBePatched.exePath = "bin/hello"; # <- not the main one, the outer wrapper module will thus not wrap it automatically.
                  flags."--greeting" = "Hello,\0 ${placeholder "out"}";
                }
              )
            ];
          }
        )
      ];
      originalPath = "${wrappedPackage.configuration.package}";
      wrappedPath = "${wrappedPackage}/bin/fileToBePatched";
    in
    {
      noOriginalReferences = {
        cond = "! grep -qF '${originalPath}' '${wrappedPath}' ";
        msg = "Desktop file still contains reference to original package. Original path: ${originalPath}";
      };
      containsWrappedReferences = fileContains wrappedPath wrappedPackage;
    };
}
