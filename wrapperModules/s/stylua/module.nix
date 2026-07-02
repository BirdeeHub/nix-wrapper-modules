{
  wlib,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options = {
    customStyle = lib.mkOption {
      type = wlib.types.structuredValueWith {
        nullable = false;
        typeName = "TOML";
      };
      default = { };
      description = ''
        nix configuration for the stylua.

        Check [StyLua options](https://github.com/JohnnyMorganz/StyLua/blob/main/README.md#options).
      '';
      example = lib.literalExpression ''
        settings = {
          call_parentheses = "Always";
          column_width = 100;
          collapse_simple_statement = "Always";
          indent_type = "Spaces";
          indent_width = 2;
          quote_style = "ForceDouble";
          sort_requires.enabled = true;
        };
      '';
    };
    generateCpScript = lib.mkEnableOption ''
      generate a copy script.

      The script `cp_stylua_toml` copys the generated `stylua.toml` file into the $CWD
      in case you want to include it in the repo.
      With the `-d|--default` option, will copy the default configuration file
      (named `stylua.default.toml`).
      Both files include all available options.
    '';
  };
  config = {
    package = lib.mkDefault pkgs.stylua;
    constructFiles.generatedConfig = lib.mkIf (config.customStyle
      != {}) {
      content = builtins.toJSON config.customStyle;
      relPath = "styles/stylua.toml";
      builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
    };
    constructFiles."cp_stylua_toml" = lib.mkIf config.generateCpScript {
      relPath = "bin/cp_stylua_toml";
      builder = "cp $1 $2 && chmod +x $2";
      content = ''
        #!${pkgs.bash}/bin/sh
        help=$'cp_stylua_toml [-h|--help|-d|--default]\nCopy stylua files.\nOptions:\n\t-h|--help\tPrint this help\n\t-d|--default\tCopy the default style file'
        if [ "$#" -ne 1 ]; then
          source=${placeholder config.outputName}/styles/stylua.toml
        elif [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
          echo "$help"
          exit 0
        elif [ "$1" == "-d" ] || [ "$1" == "--default" ]; then
          source=${placeholder config.outputName}/styles/stylua.default.toml
        fi
        cp $source $(pwd)/
      '';
    };
    flags."--config-path" = config.constructFiles."stylua.toml".path;
    meta = {
      maintainers = with wlib.maintainers; [
        kuppo
      ];
      description = ''
        Wrapper Module for [Stylua](https://github.com/JohnnyMorganz/StyLua).

        The wrapper is used to customize the `stylua.toml` file. 
        You can add you options into `config.customStyle` with pure nix expressions.

        The wrapper also provides a script which copys the generated `stylua.toml` or
        the default style file into the CWD,
        in case you want to include the confitugation into the repo.
      '';
    };
  };
}
