{
  pkgs,
  self,
  lib,
  ...
}:

let
  module =
    {
      config,
      pkgs,
      lib,
      wlib,
      ...
    }:
    {
      options.testSpecOption = lib.mkOption {
        type = lib.types.attrsOf (
          wlib.types.specWith {
            modules = [
              (
                { config, ... }:
                {
                  options = {
                    theMainField = lib.mkOption {
                      type = lib.types.either (lib.types.functionTo lib.types.raw) lib.types.str;
                    };
                    anotherField = lib.mkOption {
                      type = lib.types.str;
                      default = "a default value";
                    };
                    aDependentField = lib.mkOption {
                      type = lib.types.str;
                      default = "${config.theMainField} plus some extra";
                    };
                  };
                }
              )
            ];
          }
        );
      };
      config.testSpecOption.test1.theMainField = "test1 value";
      config.testSpecOption.test2 = "test2 value";
      config.testSpecOption.test3 = _: {
        theMainField = "test3 value";
      };
      config.package = pkgs.hello;
    };
  partial = (self.lib.evalModule module).config;
  dontConvertFns = partial.apply (
    { lib, wlib, ... }:
    {
      options.testSpecOption = lib.mkOption {
        type = lib.types.attrsOf (
          wlib.types.specWith {
            dontConvertFunctions = true;
            modules = [ ];
          }
        );
      };
    }
  );
in
pkgs.runCommand "specWith-test" { } ''
  echo "Testing spec type..."

  if [ ${lib.escapeShellArg partial.testSpecOption.test1.theMainField} != ${lib.escapeShellArg "test1 value"} ]; then
    echo 'test failed, expected `test1 value`, but `theMainField` was: ${partial.testSpecOption.test1.theMainField}'
    exit 1
  fi
  if [ ${lib.escapeShellArg partial.testSpecOption.test1.aDependentField} != ${lib.escapeShellArg "test1 value plus some extra"} ]; then
    echo 'test failed, expected `test1 value plus some extra`, but `aDependentField` was: ${partial.testSpecOption.test1.aDependentField}'
    exit 1
  fi
  if [ ${lib.escapeShellArg partial.testSpecOption.test1.anotherField} != ${lib.escapeShellArg "a default value"} ]; then
    echo 'test failed, expected `a default value`, but `anotherField` was: ${partial.testSpecOption.test1.anotherField}'
    exit 1
  fi

  if [ ${lib.escapeShellArg partial.testSpecOption.test2.theMainField} != ${lib.escapeShellArg "test2 value"} ]; then
    echo 'test failed, expected `test2 value`, but `theMainField` was: ${partial.testSpecOption.test2.theMainField}'
    exit 1
  fi
  if [ ${lib.escapeShellArg partial.testSpecOption.test2.aDependentField} != ${lib.escapeShellArg "test2 value plus some extra"} ]; then
    echo 'test failed, expected `test2 value plus some extra`, but `aDependentField` was: ${partial.testSpecOption.test2.aDependentField}'
    exit 1
  fi

  if [ ${lib.escapeShellArg (partial.testSpecOption.test3.theMainField null).theMainField} != ${lib.escapeShellArg "test3 value"} ]; then
    echo 'test failed, expected `test3 value`, but `(theMainField null).theMainField` was: ${lib.escapeShellArg (partial.testSpecOption.test3.theMainField null).theMainField}'
    exit 1
  fi
  if [ ${lib.escapeShellArg dontConvertFns.testSpecOption.test3.theMainField} != ${lib.escapeShellArg "test3 value"} ]; then
    echo 'test failed, expected `test3 value`, but `theMainField` was: ${lib.escapeShellArg dontConvertFns.testSpecOption.test3.theMainField}'
    exit 1
  fi

  echo "SUCCESS: spec type test passed"
  touch $out
''
