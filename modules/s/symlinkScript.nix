{
  config,
  lib,
  wlib,
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
  config.extraDrvAttrs.nativeBuildInputs = lib.mkIf ((config.filesToPatch or [ ]) != [ ]) [
    config.pkgs.replace
  ];
  config.symlinkScript = lib.mkDefault (
    {
      config,
      wlib,
      wrapper,
      outputs,
      exePath,
      binName,
      # other args from callPackage
      lib,
      lndir,
      ...
    }:
    let
      inherit (config)
        package
        aliases
        filesToPatch
        filesToExclude
        ;
      originalOutputs = wlib.getPackageOutputsSet package;
    in
    ''
      # Symlink all paths to the main output
      mkdir -p $out
      for path in ${
        lib.concatStringsSep " " (
          map toString (
            (lib.optional (wrapper != null) wrapper)
            ++ [
              package
            ]
          )
        )
      }; do
        ${lndir}/bin/lndir -silent "$path" $out
      done

      # Exclude specified files
      ${lib.optionalString (filesToExclude != [ ]) ''
        echo "Excluding specified files..."
        ${lib.concatMapStringsSep "\n" (pattern: ''
          for file in $out/${pattern}; do
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
        oldPath="${package}"
        newPath="$out"

        # Process each file pattern
        ${lib.concatMapStringsSep "\n" (pattern: ''
          for file in $out/${pattern}; do
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

      # Create symlinks for aliases
      ${lib.optionalString (aliases != [ ] && binName != null && binName != "") ''
        mkdir -p $out/bin
        for alias in ${lib.concatStringsSep " " (map lib.escapeShellArg aliases)}; do
          ln -sf ${lib.escapeShellArg binName} $out/bin/$alias
        done
      ''}

      # Handle additional outputs by symlinking from the original package's outputs
      ${lib.concatMapStringsSep "\n" (
        output:
        if output != "out" && originalOutputs ? ${output} && originalOutputs.${output} != null then
          ''
            if [[ -n "''${${output}:-}" ]]; then
              mkdir -p ${"$" + output}
              # Only symlink from the original package's corresponding output
              ${lndir}/bin/lndir -silent "${originalOutputs.${output}}" ${"$" + output}
            fi
          ''
        else
          ""
      ) outputs}

    ''
  );
}
