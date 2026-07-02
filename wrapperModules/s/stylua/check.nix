{
  pkgs,
  self,
  tlib,
  ...
}:
let
  inherit (tlib)
    fileContains
    isDirectory
    isFile
    notIsFile
    areEqual
    test
    ;
in
test { wrapper = "stylua"; } {
  "stylua wrapper test" =
    let
      default = self.wrappers.stylua.wrap {
        inherit pkgs;
      };
      styluaWrapper = default.wrap {
        customStyle = {
          call_parentheses = "Always";
          column_width = 100;
        };
      };
      cpScriptWrapper = styluaWrapper.wrap {
        generateCpScript = {
          enable = true;
        };
      };
      cpScriptNameWrapper = cpScriptWrapper.wrap {
        generateCpScript = {
          name = "./bin/test_script";
        };
      };
      styluaTomlContent = ''
        call_parentheses = "Always"
        column_width = 100
      '';
    in
    [
      (isDirectory default)
      (notIsFile "${default}/styles/stylua.toml")
      (notIsFile "${default}/bin/cp_stylua_toml")

      (isDirectory styluaWrapper)
      (isFile "${styluaWrapper}/styles/stylua.toml")
      (fileContains "${styluaWrapper}/styles/stylua.toml" "${styluaTomlContent}")
      (notIsFile "${styluaWrapper}/bin/cp_stylua_toml")

      (isDirectory cpScriptWrapper)
      (isFile "${cpScriptWrapper}/styles/stylua.toml")
      (fileContains "${cpScriptWrapper}/styles/stylua.toml" "${styluaTomlContent}")
      (isFile "${cpScriptWrapper}/bin/cp_stylua_toml")
      (fileContains "${cpScriptWrapper}/bin/cp_stylua_toml" "bin/sh")

      (isDirectory cpScriptNameWrapper)
      (isFile "${cpScriptNameWrapper}/styles/stylua.toml")
      (fileContains "${cpScriptNameWrapper}/styles/stylua.toml" "${styluaTomlContent}")
      (isFile "${cpScriptNameWrapper}/bin/test_script")
      (fileContains "${cpScriptNameWrapper}/bin/test_script" "bin/sh")

      # test the copy script
      ''
        cd /tmp && ${cpScriptNameWrapper}/bin/test_script && \
        [[ -e /tmp/stylua.toml ]] && [[ -w /tmp/stylua.toml ]] && \
        grep -i "always" /tmp/stylua.toml && rm -f /tmp/stylua.toml
      ''

      ''
        ${cpScriptNameWrapper}/bin/test_script -h |
        grep -i "add-doc"
      ''

      ''
        ${cpScriptNameWrapper}/bin/test_script --help |
        grep -i "add-doc"
      ''

      ''
        cd /tmp && ${cpScriptNameWrapper}/bin/test_script -i && \
        [[ -e /tmp/stylua.toml ]] && [[ -w /tmp/stylua.toml ]] && \
        grep -i "formatting options" /tmp/stylua.toml && rm -f /tmp/stylua.toml
      ''

      ''
        cd /tmp && ${cpScriptNameWrapper}/bin/test_script --add-doc && \
        [[ -e /tmp/stylua.toml ]] && [[ -w /tmp/stylua.toml ]] && \
        grep -i "formatting options" /tmp/stylua.toml && rm -f /tmp/stylua.toml
      ''
    ];
}
