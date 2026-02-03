{
  pkgs,
  self,
}:
let
  luaEnv = self.lib.makeCustomizable "withPackages" {
    mergeArgs =
      og: new: lp:
      og lp ++ new lp;
  } pkgs.luajit.withPackages (lp: [ lp.inspect ]);

  # inspect + cjson
  luaEnv2 = luaEnv.withPackages (lp: [ lp.cjson ]);
  # inspect + cjson + luassert
  luaEnv3 = luaEnv2.withPackages (lp: [ lp.luassert ]);
  # inspect + cjson + luassert + luafilesystem
  luaEnv4 = luaEnv3.withPackages (lp: [ lp.luafilesystem ]);

  getPkgs = v: pkgs.lib.escapeShellArg v.drvAttrs.pkgs;
in
pkgs.runCommand "makeCustomizable-test" { } ''

  if ! echo ${getPkgs luaEnv} | grep -q "inspect"; then
    echo "FAILURE: makeCustomizable test failed (inspect)"
    exit 1
  fi

  if ! echo ${getPkgs luaEnv2} | grep -q "inspect"; then
    echo "FAILURE: makeCustomizable test 2 failed (inspect)"
    exit 1
  fi

  if ! echo ${getPkgs luaEnv2} | grep -q "cjson"; then
    echo "FAILURE: makeCustomizable test 2 failed (cjson)"
    exit 1
  fi

  if ! echo ${getPkgs luaEnv3} | grep -q "inspect"; then
    echo "FAILURE: makeCustomizable test 3 failed (inspect)"
    exit 1
  fi

  if ! echo ${getPkgs luaEnv3} | grep -q "cjson"; then
    echo "FAILURE: makeCustomizable test 3 failed (cjson)"
    exit 1
  fi

  if ! echo ${getPkgs luaEnv3} | grep -q "luassert"; then
    echo "FAILURE: makeCustomizable test 3 failed (luassert)"
    exit 1
  fi

  if ! echo ${getPkgs luaEnv4} | grep -q "inspect"; then
    echo "FAILURE: makeCustomizable test 4 failed (inspect)"
    exit 1
  fi

  if ! echo ${getPkgs luaEnv4} | grep -q "cjson"; then
    echo "FAILURE: makeCustomizable test 4 failed (cjson)"
    exit 1
  fi

  if ! echo ${getPkgs luaEnv4} | grep -q "luassert"; then
    echo "FAILURE: makeCustomizable test 4 failed (luassert)"
    exit 1
  fi

  if ! echo ${getPkgs luaEnv4} | grep -q "luafilesystem"; then
    echo "FAILURE: makeCustomizable test 4 failed (luafilesystem)"
    exit 1
  fi

  echo "SUCCESS: makeCustomizable test passed (including multi-level chaining)"
  touch $out
''
