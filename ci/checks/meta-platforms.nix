{
  pkgs,
  self,
}:

let
  # Test 1: Default platforms (should be lib.platforms.all)
  helloModuleDefault = self.lib.wrapModule (
    { config, pkgs, ... }:
    {
      config.package = pkgs.hello;
    }
  );

  moduleConfigDefault = helloModuleDefault.apply { inherit pkgs; };

  # Test 2: Custom platforms (linux only)
  helloModuleLinux = self.lib.wrapModule (
    { config, pkgs, ... }:
    {
      config.package = pkgs.hello;
      config.meta.platforms = pkgs.lib.platforms.linux;
    }
  );

  moduleConfigLinux = helloModuleLinux.apply { inherit pkgs; };

  # Test 3: Specific platforms list
  helloModuleSpecific = self.lib.wrapModule (
    { config, pkgs, ... }:
    {
      config.package = pkgs.hello;
      config.meta.platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    }
  );

  moduleConfigSpecific = helloModuleSpecific.apply { inherit pkgs; };

in
pkgs.runCommand "meta-platforms-test" { } ''
  echo "Testing meta.platforms field..."

  # Test 1: Check default platforms
  defaultPlatforms='${builtins.toJSON moduleConfigDefault.meta.platforms}'
  echo "Default platforms: $defaultPlatforms"

  if [ "$defaultPlatforms" = "[]" ]; then
    echo "FAIL: Default platforms should not be empty"
    exit 1
  fi

  # Check that default includes common platforms
  if ! echo "$defaultPlatforms" | grep -q "x86_64-linux"; then
    echo "FAIL: Default platforms should include x86_64-linux"
    exit 1
  fi

  # Test 2: Check Linux-only platforms
  linuxPlatforms='${builtins.toJSON moduleConfigLinux.meta.platforms}'
  echo "Linux platforms: $linuxPlatforms"

  if ! echo "$linuxPlatforms" | grep -q "x86_64-linux"; then
    echo "FAIL: Linux platforms should include x86_64-linux"
    exit 1
  fi

  if ! echo "$linuxPlatforms" | grep -q "aarch64-linux"; then
    echo "FAIL: Linux platforms should include aarch64-linux"
    exit 1
  fi

  # Should not include darwin when set to linux only
  if echo "$linuxPlatforms" | grep -q "darwin"; then
    echo "FAIL: Linux platforms should not include darwin"
    exit 1
  fi

  # Test 3: Check specific platforms list
  specificPlatforms='${builtins.toJSON moduleConfigSpecific.meta.platforms}'
  echo "Specific platforms: $specificPlatforms"

  if ! echo "$specificPlatforms" | grep -q "x86_64-linux"; then
    echo "FAIL: Specific platforms should include x86_64-linux"
    exit 1
  fi

  if ! echo "$specificPlatforms" | grep -q "aarch64-linux"; then
    echo "FAIL: Specific platforms should include aarch64-linux"
    exit 1
  fi

  # Should only have the two platforms we specified
  platformCount=$(echo "$specificPlatforms" | grep -o 'linux' | wc -l | tr -d ' ')
  if [ "$platformCount" != "2" ]; then
    echo "FAIL: Specific platforms should have exactly 2 platforms, got $platformCount"
    exit 1
  fi

  # Verify it doesn't contain other platforms
  if echo "$specificPlatforms" | grep -q "darwin"; then
    echo "FAIL: Specific platforms should not include darwin"
    exit 1
  fi

  echo "SUCCESS: meta.platforms test passed"
  touch $out
''
