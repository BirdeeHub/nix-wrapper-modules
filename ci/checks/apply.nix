{
  pkgs,
  self,
}:
# TODO: make sure theres no other stuff passing on accident in here
let
  # Create a simple wrapper module
  helloModule =
    (self.lib.evalModule (
      {
        config,
        wlib,
        pkgs,
        ...
      }:
      {
        config.package = pkgs.hello;
        imports = [ wlib.modules.default ];
        config.flags = {
          "--greeting" = "initial";
        };
      }
    )).config;

  # Apply with initial settings
  initialConfig = helloModule.apply {
    inherit pkgs;
    flags."--verbose" = true;
  };

  # Extend the configuration
  extendedConfig = initialConfig.apply (
    { lib, ... }:
    {
      flags."--greeting" = lib.mkForce "extended";
      flags."--extra" = "flag";
    }
  );

  # Test mkForce to override a value
  forcedConfig = initialConfig.apply (
    { lib, ... }:
    {
      flags."--greeting" = lib.mkForce "forced";
      flags."--forced-flag" = lib.mkForce "forced";
    }
  );

  # Test extending via wrapper.passthru.configuration.apply
  passthruExtendedConfig = initialConfig.wrapper.passthru.configuration.apply {
    flags."--passthru" = "test";
  };

  # Test chaining apply multiple levels deep
  doubleApply = extendedConfig.apply {
    flags."--greeting" = "double";
    flags."--double" = "level2";
  };

  tripleApply = doubleApply.apply {
    flags."--greeting" = "triple";
    flags."--triple" = "level3";
  };

in
pkgs.runCommand "extend-test" { } ''
  echo "Testing apply function..."

  initialScript="${initialConfig.wrapper}/bin/hello"
  extendedScript="${extendedConfig.wrapper}/bin/hello"
  forcedScript="${forcedConfig.wrapper}/bin/hello"
  passthruExtendedScript="${passthruExtendedConfig.wrapper}/bin/hello"
  doubleScript="${doubleApply.wrapper}/bin/hello"
  tripleScript="${tripleApply.wrapper}/bin/hello"

  # Check initial config has initial greeting
  if ! grep -q "initial" "$initialScript"; then
    echo "FAIL: initial config should have 'initial' greeting"
    cat "$initialScript"
    exit 1
  fi

  # Check initial config has verbose flag
  if ! grep -q -- "--verbose" "$initialScript"; then
    echo "FAIL: initial config should have --verbose"
    cat "$initialScript"
    exit 1
  fi

  # Check extended config has extended greeting (overriding initial)
  if ! grep -q "extended" "$extendedScript"; then
    echo "FAIL: extended config should have 'extended' greeting"
    cat "$extendedScript"
    exit 1
  fi

  # Check extended config has verbose flag (preserved from initial apply)
  if ! grep -q -- "--verbose" "$extendedScript"; then
    echo "FAIL: extended config should preserve --verbose"
    cat "$extendedScript"
    exit 1
  fi

  # Check extended config has extra flag (from apply)
  if ! grep -q -- "--extra" "$extendedScript"; then
    echo "FAIL: extended config should have --extra flag"
    cat "$extendedScript"
    exit 1
  fi

  # Check mkForce override works
  if ! grep -q "forced" "$forcedScript"; then
    echo "FAIL: forced config should have 'forced' greeting"
    cat "$forcedScript"
    exit 1
  fi

  # Check that mkForce overrode both initial and apply settings
  if grep -q "initial" "$forcedScript"; then
    echo "FAIL: forced config should not have 'initial' greeting (should be overridden by mkForce)"
    cat "$forcedScript"
    exit 1
  fi

  # Check forced config has forced-flag
  if ! grep -q -- "--forced-flag" "$forcedScript"; then
    echo "FAIL: forced config should have --forced-flag"
    cat "$forcedScript"
    exit 1
  fi

  # Check passthru.configuration.apply works
  if ! grep -q -- "--passthru" "$passthruExtendedScript"; then
    echo "FAIL: passthru extended config should have --passthru flag"
    cat "$passthruExtendedScript"
    exit 1
  fi

  # Check passthru extended config preserves original settings
  if ! grep -q -- "--verbose" "$passthruExtendedScript"; then
    echo "FAIL: passthru extended config should preserve --verbose"
    cat "$passthruExtendedScript"
    exit 1
  fi

  # Check double apply - greeting should be "double" (not "extended")
  if ! grep -q "double" "$doubleScript"; then
    echo "FAIL: double apply should have 'double' greeting"
    cat "$doubleScript"
    exit 1
  fi

  # Check double apply preserves all previous flags
  if ! grep -q -- "--verbose" "$doubleScript"; then
    echo "FAIL: double apply should preserve --verbose from initial"
    cat "$doubleScript"
    exit 1
  fi

  if ! grep -q -- "--extra" "$doubleScript"; then
    echo "FAIL: double apply should preserve --extra from extended"
    cat "$doubleScript"
    exit 1
  fi

  if ! grep -q -- "--double" "$doubleScript"; then
    echo "FAIL: double apply should have --double flag"
    cat "$doubleScript"
    exit 1
  fi

  # Check triple apply - greeting "extended" (the one with mkForce wins)
  if ! grep -q "extended" "$tripleScript"; then
    echo "FAIL: triple apply should have 'extended' greeting"
    cat "$tripleScript"
    exit 1
  fi

  # Check triple apply preserves all previous flags
  if ! grep -q -- "--verbose" "$tripleScript"; then
    echo "FAIL: triple apply should preserve --verbose"
    cat "$tripleScript"
    exit 1
  fi

  if ! grep -q -- "--extra" "$tripleScript"; then
    echo "FAIL: triple apply should preserve --extra"
    cat "$tripleScript"
    exit 1
  fi

  if ! grep -q -- "--double" "$tripleScript"; then
    echo "FAIL: triple apply should preserve --double"
    cat "$tripleScript"
    exit 1
  fi

  if ! grep -q -- "--triple" "$tripleScript"; then
    echo "FAIL: triple apply should have --triple flag"
    cat "$tripleScript"
    exit 1
  fi

  echo "SUCCESS: apply test passed (including multi-level chaining)"
  touch $out
''
