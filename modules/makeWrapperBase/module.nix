{
  config,
  wlib,
  lib,
  ...
}:
{
  options.rawWrapperArgs = lib.mkOption {
    type = wlib.types.wrapperFlag;
    default = [ ];
    example = [
      "--inherit-argv0"
      [
        "--add-flag"
        "--config"
        "--add-flag"
        "\${./storePath.cfg}"
      ]
      {
        name = "target";
        data = "--add-flag";
      }
      [
        "-s"
        "idk"
      ]
      {
        after = [ "target" ];
        data = "moved_to_after_target";
      }
    ];
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
    example = [
      "--inherit-argv0"
      [
        "--add-flag"
        "--config"
        "--add-flag"
        "\${./storePath.cfg}"
      ]
      {
        name = "target";
        data = "--add-flag";
      }
      [
        "-s"
        "idk"
      ]
      {
        after = [ "target" ];
        data = "moved_to_after_target";
      }
    ];
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
  config.extraDrvAttrs.nativeBuildInputs = [
    (if config.makeWrapper != null then config.makeWrapper else config.pkgs.makeWrapper)
  ];
  config.wrapperFunction = lib.mkDefault (
    {
      config,
      wlib,
      ...
    }:
    let
      baseArgs = lib.escapeShellArgs [
        (if config.exePath == "" then "${config.package}" else "${config.package}/${config.exePath}")
        "${placeholder "out"}/bin/${config.binName}"
      ];
      finalArgs = lib.pipe config.rawWrapperArgs [
        (wlib.dag.lmap (v: if builtins.isList v then map lib.escapeShellArg v else lib.escapeShellArg v))
        (v: v ++ config.unsafeWrapperArgs)
        (
          dag:
          wlib.dag.sortAndUnwrap {
            inherit dag;
            mapIfOk = v: v.data;
          }
        )
        lib.flatten
      ];
    in
    if config.binName == "" then
      ""
    else
      "makeWrapper ${baseArgs} ${builtins.concatStringsSep " " finalArgs}"
  );
  config.meta.maintainers = lib.mkDefault [ lib.maintainers.birdee ];
}
