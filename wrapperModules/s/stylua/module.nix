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
    generateCpScript = lib.mkOption {
      default = { };
      description = ''
        Options for copy script which help you quickly copy your
        settings into `$CWD` for further customization.

        The script `cp_stylua_toml` (name is customizable) copys the generated
        `stylua.toml` file into '$CWD' in case you want to include it in the
        repo or customize it.

        With the `-i|--add-doc` option, it will add the configuraiton
        documentation to the end of the copied file.
      '';
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption ''
            generating a copy script.
          '';
          name = lib.mkOption {
            type = lib.types.str;
            default = "cp_stylua_toml";
            description = ''
              Customize the name of the copy script. If the name has `/` in it,
              the wrapper will only take the file's base name.
            '';
          };
        };
      };
    };
  };
  config = {
    package = lib.mkDefault pkgs.stylua;
    constructFiles.generatedConfig = lib.mkIf (config.customStyle != { }) {
      content = builtins.toJSON config.customStyle;
      relPath = "styles/stylua.toml";
      builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
    };
    constructFiles."${baseNameOf config.generateCpScript.name}" =
      lib.mkIf config.generateCpScript.enable
        {
          relPath = "bin/${baseNameOf config.generateCpScript.name}";
          builder = "cp $1 $2 && chmod +x $2";
          content = ''
            #!${pkgs.bash}/bin/sh
            help=$'cp_stylua_toml [-h|--help|-i|--add-doc]\nCopy stylua files.\nOptions:\n\t-h|--help\tPrint this help\n\t-i|--add-doc\tAdd the configuration doccumentation to the end of the stylua.toml'

            target=$(pwd)/stylua.toml

            doc=$(${placeholder config.outputName}/bin/stylua --help \
            | ${pkgs.gnused}/bin/sed -n \
            '/^FORMATTING OPTIONS:$/,$ {1d;s/^[[:space:]]*/   /;s/^[[:space:]]*--/** /;s/^/# /;p}')

            if [ "$#" -ne 1 ]; then
              cp -f ${placeholder config.outputName}/styles/stylua.toml $(pwd)/ \
              && chmod u+w "$target"
            elif [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
              echo "$help"
              exit 0
            elif [ "$1" == "-i" ] || [ "$1" == "--add-doc" ]; then
              cp -f ${placeholder config.outputName}/styles/stylua.toml $(pwd)/ \
              && chmod u+w "$target" && echo >> "$target" && echo "$doc" >> "$target"
            fi
          '';
        };
    flags."--config-path" = lib.mkIf (
      config.customStyle != { }
    ) config.constructFiles.generatedConfig.path;
    meta = {
      maintainers = with wlib.maintainers; [
        kuppo
      ];
      description = ''
        Wrapper Module for [Stylua](https://github.com/JohnnyMorganz/StyLua).

        The wrapper is used to customize the `stylua.toml` file.
        You can add you options into `config.customStyle` with pure nix expressions.

        The wrapper also provides a script which copys the generated `stylua.toml`
        into `$CWD`, in case you want to include the confitugation into the repo or
        customize it somehow.
      '';
    };
  };
}
