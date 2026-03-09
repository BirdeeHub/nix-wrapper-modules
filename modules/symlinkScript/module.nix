{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
{
  options = {
    aliases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Aliases for the package to also be added to the PATH";
    };
    filesToPatch = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "share/applications/*.desktop" ];
      description = ''
        List of file paths (glob patterns) relative to package root to patch for self-references.
        Desktop files are patched by default to update Exec= and Icon= paths.
      '';
    };
    filesToExclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        List of file paths (glob patterns) relative to package root to exclude from the wrapped package.
        This allows filtering out unwanted binaries or files.
        Example: `[ "bin/unwanted-tool" "share/applications/*.desktop" ]`
      '';
    };
  };
  config.drv.nativeBuildInputs = lib.mkIf ((config.filesToPatch or [ ]) != [ ]) [
    pkgs.replace
  ];
  config.builderFunction = lib.mkDefault (
    {
      config,
      wlib,
      wrapper,
      # other args from callPackage
      lib,
      lndir,
      ...
    }:
    let
      inherit (config)
        package
        aliases
        outputName
        wrapperPaths
        filesToPatch
        filesToExclude
        binName
        outputs
        ;
      originalOutputs = wlib.getPackageOutputsSet package;
    in
    "mkdir -p ${placeholder outputName} \n"
    + (
      if builtins.isString wrapper then
        wrapper
      else if wrapper != null then
        "${lndir}/bin/lndir -silent \"${toString wrapper}\" ${placeholder outputName}"
      else
        ""
    )
    + ''

      # Handle additional outputs by symlinking from the original package's outputs
      ${lib.concatMapStringsSep "\n" (
        output:
        if originalOutputs ? ${output} && originalOutputs.${output} != null then
          ''

            if [[ -n "''${${output}:-}" ]]; then
              mkdir -p ${placeholder output}
              # Only symlink from the original package's corresponding output
              ${lndir}/bin/lndir -silent "${originalOutputs.${output}}" ${placeholder output}
            fi

            # Exclude specified files for ${output}
            ${lib.optionalString (filesToExclude != [ ]) ''
              echo "Excluding specified files..."
              ${lib.concatMapStringsSep "\n" (pattern: ''
                for file in ${placeholder output}/${pattern}; do
                  if [[ -e "$file" ]]; then
                    echo "Removing $file"
                    rm -f "$file"
                  fi
                done
              '') filesToExclude}
            ''}

            # Patch specified files to replace references to the original package with the wrapped one
            ${lib.optionalString (filesToPatch != [ ]) ''
              echo "Patching self-references in specified files..."
              oldPath="${originalOutputs.${output}}"
              newPath="${placeholder output}"

              # Process each file pattern
              ${lib.concatMapStringsSep "\n" (pattern: ''
                for file in ${placeholder output}/${pattern}; do
                  if [[ -L "$file" ]]; then
                    # It's a symlink, we need to resolve it
                    target=$(readlink -f "$file")

                    # Check if the file contains the old path
                    if grep -qF "$oldPath" "$target" 2>/dev/null; then
                      echo "Patching $file"
                      # Remove symlink and create a real file with patched content
                      rm "$file"
                      # Use replace-literal which works for both text and binary files
                      replace-literal "$oldPath" "$newPath" < "$target" > "$file"
                      # Preserve permissions
                      chmod --reference="$target" "$file"
                    fi
                  fi
                done
              '') filesToPatch}
            ''}

          ''
        else
          ""
      ) outputs}

      # Create symlinks for aliases
      ${lib.optionalString (aliases != [ ] && binName != "") ''
        mkdir -p ${placeholder outputName}/bin
        for alias in ${lib.concatStringsSep " " (map lib.escapeShellArg aliases)}; do
          ln -sf ${wrapperPaths.placeholder} ${placeholder config.outputName}/bin/$alias
        done
      ''}

    ''
  );
  config.meta.maintainers = [ wlib.maintainers.birdee ];
  config.meta.description = ''
    Adds extra options compared to the default `builderFunction` option value.

    Imported by `wlib.modules.default`

    ---
  '';
}
