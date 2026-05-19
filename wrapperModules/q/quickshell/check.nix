{
  pkgs,
  self,
  ...
}:
let
  quickshellWrapped = self.wrappers.quickshell.wrap {
    inherit pkgs;
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
pkgs.runCommand "quickshell-test"
  {
    LANG = "C.utf8";
    LC_ALL = "C.utf8";
  }
  ''
    set +e

    export XDG_RUNTIME_DIR=$(${pkgs.coreutils}/bin/mktemp -d)
    logs=$("${quickshellWrapped}/bin/quickshell" -v -v 2>&1)

    echo "$logs" | grep -q "Scanning qml file "${quickshellWrapped}/shell.qml""
    echo "$logs" | grep -q "Scanning qml file "${quickshellWrapped}/Bar.qml""

    touch $out
  ''
