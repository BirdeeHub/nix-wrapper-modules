{
  pkgs,
  self,
  tlib,
  ...
}:
let
  inherit (tlib)
    isDirectory
    isFile
    test
    ;
in
test { wrapper = "quickshell"; } {
  "wrapper should output correct version" =
    let
      wrapper = self.wrappers.quickshell.wrap {
        inherit pkgs;
      };
    in
    ''
      "${wrapper}/bin/quickshell" --version |
      grep -q "${wrapper.version}"
    '';

  "wrapper should create config dir" =
    let
      wrapper = self.wrappers.quickshell.wrap {
        inherit pkgs;
      };
    in
    isDirectory "${wrapper}/${wrapper.passthru.configuration.binName}-config";

  "wrapper should load shell.qml and components" =
    let
      wrapper = self.wrappers.quickshell.wrap {
        inherit pkgs;

        env.LANG = "C.utf8";
        env.LC_ALL = "C.utf8";
        env.XDG_RUNTIME_DIR = "/tmp";

        configFile.content = ''
          Scope {
            Bar {}
          }
        '';

        components.bar.content = ''
          import Quickshell // for PanelWindow
          import QtQuick // for Text

          PanelWindow {
            anchors {
              top: true
              left: true
              right: true
            }

            implicitHeight: 30

            Text {
              anchors.centerIn: parent
              text: "hello world"
            }
          }
        '';
      };
    in
    [
      (isFile "${wrapper}/${wrapper.passthru.configuration.binName}-config/shell.qml")
      (isFile "${wrapper}/${wrapper.passthru.configuration.binName}-config/Bar.qml")
      ''
        logs=$("${wrapper}/bin/quickshell" 2>&1)
        echo "$logs" | grep -q "Launching config: \"${wrapper}/${wrapper.passthru.configuration.binName}-config/shell.qml\""
      ''
    ];
}
