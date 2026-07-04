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
          call_parentheses = "None";
          column_width = 100;
          quote_style = "ForceSingle";
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
      cpScriptOnlyWrapper = default.wrap {
        generateCpScript.enable = true;
      };
      styluaTomlContent = ''
        call_parentheses = "None"
        column_width = 100
        quote-style = "ForceSingle"
      '';
      styluaFile = "styles/stylua.toml";
      styluaToml = "/tmp/stylua.toml";
    in
    [
      (isDirectory default)
      (notIsFile "${default}/${styluaFile}")
      (notIsFile "${default}/bin/cp_stylua_toml")

      (isDirectory styluaWrapper)
      (isFile "${styluaWrapper}/${styluaFile}")
      (fileContains "${styluaWrapper}/${styluaFile}" "${styluaTomlContent}")
      (notIsFile "${styluaWrapper}/bin/cp_stylua_toml")

      (isDirectory cpScriptWrapper)
      (isFile "${cpScriptWrapper}/${styluaFile}")
      (fileContains "${cpScriptWrapper}/${styluaFile}" "${styluaTomlContent}")
      (isFile "${cpScriptWrapper}/bin/cp_stylua_toml")
      (fileContains "${cpScriptWrapper}/bin/cp_stylua_toml" "bin/sh")

      (isDirectory cpScriptNameWrapper)
      (isFile "${cpScriptNameWrapper}/${styluaFile}")
      (fileContains "${cpScriptNameWrapper}/${styluaFile}" "${styluaTomlContent}")
      (isFile "${cpScriptNameWrapper}/bin/test_script")
      (fileContains "${cpScriptNameWrapper}/bin/test_script" "bin/sh")

      (isDirectory cpScriptOnlyWrapper)
      (isFile "${cpScriptOnlyWrapper}/bin/cp_stylua_toml")
      (notIsFile "${cpScriptOnlyWrapper}/${styluaFile}")

      ''
        cd /tmp && ${cpScriptNameWrapper}/bin/test_script && \
        [[ -e ${styluaToml} ]] && [[ -w ${styluaToml} ]] && \
        grep -i "forcesingle" ${styluaToml} && rm -f ${styluaToml}
      ''

      ''
        ${cpScriptNameWrapper}/bin/test_script -h |
        grep -i "add-doc" && [[ ! -e ${styluaToml} ]]
      ''

      ''
        ${cpScriptNameWrapper}/bin/test_script --help |
        grep -i "add-doc" && [[ ! -e ${styluaToml} ]]
      ''

      ''
        cd /tmp && ${cpScriptNameWrapper}/bin/test_script -i && \
        [[ -e ${styluaToml} ]] && [[ -w ${styluaToml} ]] && \
        grep -i 'enabled = true|false' ${styluaToml} && rm -f ${styluaToml}
      ''

      ''
        cd /tmp && ${cpScriptNameWrapper}/bin/test_script --add-doc && \
        [[ -e ${styluaToml} ]] && [[ -w ${styluaToml} ]] && \
        grep -i 'enabled = true|false' ${styluaToml} && rm -f ${styluaToml}
      ''

      ''
        cd /tmp && ${cpScriptWrapper}/bin/cp_stylua_toml && cat stylua.toml && rm -f ${styluaToml}
      ''

      ''
        cd /tmp && ${cpScriptOnlyWrapper}/bin/cp_stylua_toml | grep "have not generated stylua.toml" \
        && [[ ! -e ${styluaToml} ]]
      ''

      ''
        cd /tmp && ${cpScriptOnlyWrapper}/bin/cp_stylua_toml -i \
        && [[ -e ${styluaToml} ]] && grep 'enabled = true|false' ${styluaToml} && rm -f ${styluaToml}
      ''

      # prepare the test lua file
      ''
        echo "print 'ugly and bad but or and good'" > /tmp/test.lua
      ''

      ''
        [[ $(${styluaWrapper}/bin/stylua -c /tmp/test.lua 2>&1) == "" ]]
      ''

      ''
        output=$("${default}/bin/stylua" -c /tmp/test.lua 2>&1)
        echo "$output" | grep -q 'print("ugly and bad but or and good")'
      ''

      # clean up
      ''
        rm /tmp/test.lua
      ''
    ];
}
