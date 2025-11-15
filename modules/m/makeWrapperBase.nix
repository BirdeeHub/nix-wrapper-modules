{
  wlib,
  lib,
  ...
}:
{
  options.rawWrapperArgs = lib.mkOption {
    type = wlib.types.wrapperFlag;
    default = [ ];
    description = ''
      DAG list (DAL) or `dependency list` of wrapper arguments, escaped with `lib.escapeShellArgs`

      `wrapper arguments` refers to this:

      [pkgs/build-support/setup-hooks/make-wrapper.sh](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/setup-hooks/make-wrapper.sh)

      [pkgs/by-name/ma/makeBinaryWrapper/make-binary-wrapper.sh](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ma/makeBinaryWrapper/make-binary-wrapper.sh)

      This option takes a list. To group them more strongly,
      option may take a list of lists as well.

      Any entry can instead be of type `{ data, name ? null, before ? [], after ? [] }`

      This will cause it to be added to the DAG.

      If no name is provided, it cannot be targeted.
    '';
  };
  options.unsafeWrapperArgs = lib.mkOption {
    type = wlib.types.wrapperFlag;
    default = [ ];
    description = ''
      DAG list (DAL) or `dependency list` of wrapper arguments, concatenated with spaces

      `wrapper arguments` refers to this:

      [pkgs/build-support/setup-hooks/make-wrapper.sh](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/setup-hooks/make-wrapper.sh)

      [pkgs/by-name/ma/makeBinaryWrapper/make-binary-wrapper.sh](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ma/makeBinaryWrapper/make-binary-wrapper.sh)

      This option takes a list. To group them more strongly,
      option may take a list of lists as well.

      Any entry can instead be of type `{ data, name ? null, before ? [], after ? [] }`

      This will cause it to be added to the DAG.

      If no name is provided, it cannot be targeted.
    '';
  };
  options.makeWrapper = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = null;
    description = ''
      makeWrapper implementation to use (default `pkgs.makeWrapper`)

      prefer `useBinaryWrapper` boolean if using `wlib.modules.makeWrapper`
      as doing so will disable fields it does not support as well.
    '';
  };
  config.wrapperFunction = lib.mkDefault (
    {
      config,
      wlib,
      exePath,
      binName,
      outputs,
      pkgs,
      ...
    }:
    pkgs.runCommand "${binName}-wrapped"
      {
        nativeBuildInputs = [
          (if config.makeWrapper != null then config.makeWrapper else pkgs.makeWrapper)
        ];
      }
      (
        let
          baseArgs = lib.escapeShellArgs [
            (if exePath == "" || exePath == null then "${config.package}" else "${config.package}/${exePath}")
            "${placeholder "out"}/bin/${binName}"
          ];
          finalArgs = lib.pipe config.rawWrapperArgs [
            (wlib.dag.lmap (v: if builtins.isList v then lib.escapeShellArgs v else lib.escapeShellArg v))
            (v: v ++ config.unsafeWrapperArgs)
            (
              dag:
              wlib.dag.sortAndUnwrap {
                inherit dag;
                mapIfOk = v: v.data;
              }
            )
          ];
        in
        if binName == "" || binName == null then
          "mkdir -p $out"
        else
          "makeWrapper ${baseArgs} ${builtins.concatStringsSep " " finalArgs}"
      )
  );
}
