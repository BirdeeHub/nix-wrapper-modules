{
  pkgs,
  self,
}:
let
  xplr = self.wrapperModules.xplr.wrap (
    { lib, ... }:
    {
      inherit pkgs;
      plugins.TESTPLUGIN = pkgs.writeTextFile {
        name = "xplr-test-plugin";
        text = /* lua */ ''
          print("HELLO FROM TESTPLUGIN")
        '';
        destination = "/init.lua";
      };
      luaEnv = lp: [ lp.inspect ];
      luaInfo = {
        testvar = "HELLO FROM INFO";
      };
      luaInit.testfile = /* lua */ ''
        print("HELLO FROM CONFIG")
        os.exit(0)
      '';
      luaInit.testfile1 = {
        before = [ "testfile" ];
        type = "fnl";
        opts = {
          testvar = "HELLO FROM SNIPPET opts VAL";
        };
        data = /* fennel */ ''
          (local (opts name) ...)
          (print name ((require "inspect") opts) ((require "inspect") (require "nix-info")))
          (require "TESTPLUGIN")
        '';
      };
    }
  );
  xplr_linux_only_check = self.wrapperModules.xplr.wrap (
    { lib, ... }:
    {
      inherit pkgs;
      luaInit.testfile1 = {
        before = [ "testfile" ];
        data = "";
      };
      luaInit.testfile = /* lua */ ''
        xplr.fn.custom.my_test = function()
          print("HELLO FROM HOOK")
          os.exit(0)
        end
        return {
          on_load = {
            { LogSuccess = "Configuration successfully loaded!" },
            { CallLuaSilently = "custom.my_test" },
          },
        }
      '';
    }
  );
in
if builtins.elem pkgs.stdenv.hostPlatform.system pkgs.lib.platforms.linux then
  pkgs.runCommand "xplr-test" { } ''
    res=$(${pkgs.unixtools.script}/bin/script -q -c "${xplr}/bin/xplr" /dev/null)
    if ! echo "$res" | grep -q "HELLO FROM CONFIG"; then
      echo "$res"
      touch $out
      exit 1
    fi
    if ! echo "$res" | grep -q "HELLO FROM INFO"; then
      echo "$res"
      touch $out
      exit 1
    fi
    if ! echo "$res" | grep -q "HELLO FROM SNIPPET opts VAL"; then
      echo "$res"
      touch $out
      exit 1
    fi
    if ! echo "$res" | grep -q "HELLO FROM TESTPLUGIN"; then
      echo "$res"
      touch $out
      exit 1
    fi
    res=$(${pkgs.unixtools.script}/bin/script -q -c "${xplr_linux_only_check}/bin/xplr" /dev/null)
    if ! echo "$res" | grep -q "HELLO FROM HOOK"; then
      echo "$res"
      touch $out
      exit 1
    fi
    touch $out
  ''
else
  # NOTE: script command on mac with /dev/null
  # would probably give no end of issues. Different test for mac
  pkgs.runCommand "xplr-test" { } ''
    if ! cat '${xplr}/bin/xplr' | grep -q "LUA_PATH"; then
      cat '${xplr}/bin/xplr'
      touch $out
      exit 1
    fi
    if ! cat '${xplr}/bin/xplr' | grep -q "LUA_CPATH"; then
      cat '${xplr}/bin/xplr'
      touch $out
      exit 1
    fi
    if ! cat '${xplr}/xplr-rc.lua' | grep -q "HELLO FROM CONFIG"; then
      cat '${xplr}/xplr-rc.lua'
      touch $out
      exit 1
    fi
    if ! cat '${xplr}/xplr-rc.lua' | grep -q "HELLO FROM SNIPPET opts VAL"; then
      cat '${xplr}/xplr-rc.lua'
      touch $out
      exit 1
    fi
    if ! cat '${xplr}/xplr-plugins/nix-info.lua' | grep -q "HELLO FROM INFO"; then
      cat '${xplr}/xplr-plugins/nix-info.lua'
      touch $out
      exit 1
    fi
    if ! cat '${xplr}/xplr-plugins/TESTPLUGIN/init.lua' | grep -q "HELLO FROM TESTPLUGIN"; then
      cat '${xplr}/xplr-plugins/TESTPLUGIN/init.lua'
      touch $out
      exit 1
    fi
    touch $out
  ''
