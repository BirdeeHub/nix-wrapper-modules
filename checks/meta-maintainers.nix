{
  pkgs,
  self,
}:

let
  # Test with a nixpkgs maintainer (rycee because he has an extra field)
  # { email = ...; github = ...; githubId = ...; keys = [ ... ]; name = ...; }
  nixpkgsMaintainer = pkgs.lib.maintainers.rycee;
  helloModule = self.lib.wrapModule (
    { config, pkgs, ... }:
    {
      config.package = pkgs.hello;
      config.meta.maintainers = [ nixpkgsMaintainer ];
    }
  );

  moduleConfig = helloModule.apply { inherit pkgs; };

  esc = pkgs.lib.escapeShellArg;

in
pkgs.runCommand "meta-maintainers-test" { } ''
  echo "Testing meta.maintainers field with nixpkgs maintainer..."

  # Check that meta.maintainers is set correctly
  maintainers='${builtins.toJSON moduleConfig.meta.maintainers}'
  echo "Maintainers: $maintainers"

  # Verify the maintainer has all required fields
  if ! echo "$maintainers" | grep -q ${esc nixpkgsMaintainer.name}; then
    echo "FAIL: name ${esc nixpkgsMaintainer.name} not found in maintainers"
    exit 1
  fi

  if ! echo "$maintainers" | grep -q ${esc nixpkgsMaintainer.email}; then
    echo "FAIL: email ${esc nixpkgsMaintainer.email} not found in maintainers"
    exit 1
  fi

  if ! echo "$maintainers" | grep -q ${esc nixpkgsMaintainer.github}; then
    echo "FAIL: github ${esc nixpkgsMaintainer.github} not found in maintainers"
    exit 1
  fi

  if ! echo "$maintainers" | grep -q ${esc nixpkgsMaintainer.githubId}; then
    echo "FAIL: githubId ${esc nixpkgsMaintainer.githubId} not found in maintainers"
    exit 1
  fi

  echo "SUCCESS: meta.maintainers test passed with nixpkgs maintainer"
  touch $out
''
