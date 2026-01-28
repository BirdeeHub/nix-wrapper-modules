{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  tomlFmt = pkgs.formats.toml { };

  yazi = tomlFmt.generate "yazi" config.settings.yazi;
  keymap = tomlFmt.generate "keymap" config.settings.keymap;
  theme = tomlFmt.generate "theme" config.settings.theme;
  vfs = tomlFmt.generate "vfs" config.settings.vfs;
  package = tomlFmt.generate "package" config.settings.package;
in
{
  imports = [ wlib.modules.default ];

  options.settings = {
    yazi = lib.mkOption {
      default = { };

      description = ''
        Content of yazi.toml file.
        See the configuration reference at <https://yazi-rs.github.io/docs/configuration/yazi>
      '';

      type = lib.types.submodule {
        freeformType = tomlFmt.type;
        options = {
          mgr = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Manager settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#mgr>
            '';
            default = { };
          };

          preview = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Preview settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#preview>
            '';
            default = { };
          };

          opener = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Opener settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#opener>
            '';
            default = { };
          };

          open = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Open settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#open>
            '';
            default = { };
          };

          plugin = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Plugin settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#plugin>
            '';
            default = { };
          };

          input = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Input settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#input>
            '';
            default = { };
          };

          confirm = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Confirm settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#confirm>
            '';
            default = { };
          };

          pick = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Pick settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#pick>
            '';
            default = { };
          };

          which = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Which settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#which>
            '';
            default = { };
          };

        };
      };
    };

    keymap = lib.mkOption {
      default = { };
      description = ''
        Content of keymap.toml file.
        See the configuration reference at <https://yazi-rs.github.io/docs/configuration/keymap>
      '';

      type = lib.types.submodule {
        freeformType = tomlFmt.type;
        options = {
          mgr = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Keymap mgr settings
              See <https://yazi-rs.github.io/docs/configuration/keymap#mgr>
            '';
            default = { };

          };

          tasks = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Keymap tasks settings
              See <https://yazi-rs.github.io/docs/configuration/keymap#tasks>
            '';
            default = { };

          };

          spot = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Keymap spot settings
              See <https://yazi-rs.github.io/docs/configuration/keymap#spot>
            '';
            default = { };

          };

          pick = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Keymap pick settings
              See <https://yazi-rs.github.io/docs/configuration/keymap#pick>
            '';
            default = { };

          };

          input = lib.mkOption {
            type = tomlFmt.type;
            description = ''
              Keymap input settings
              See <https://yazi-rs.github.io/docs/configuration/keymap#input>
            '';
            default = { };

          };

          confirm = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Keymap confirm settings
              See < https://yazi-rs.github.io/docs/configuration/keymap#confirm>
            '';
            default = { };

          };

          cmp = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Keymap cmp settings
              See < https://yazi-rs.github.io/docs/configuration/keymap#cmp>
            '';
            default = { };

          };

          help = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Keymap help settings
              See < https://yazi-rs.github.io/docs/configuration/keymap#help>
            '';
            default = { };

          };
        };
      };
    };

    theme = lib.mkOption {
      default = { };
      description = ''
        Content of theme.toml file.
        See the configuration reference at <https://yazi-rs.github.io/docs/configuration/theme>
      '';

      type = lib.types.submodule {
        freeformType = tomlFmt.type;
        options = {
          flavor = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme flawor settings
              See < https://yazi-rs.github.io/docs/configuration/theme#flavor>
            '';
            default = { };
          };

          app = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme app settings
              See < https://yazi-rs.github.io/docs/configuration/theme#app>
            '';
            default = { };
          };

          mgr = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme mgr settings
              See < https://yazi-rs.github.io/docs/configuration/theme#mgr>
            '';
            default = { };

          };

          indicator = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme indicator settings
              See < https://yazi-rs.github.io/docs/configuration/theme#indicator>
            '';
            default = { };
          };

          tabs = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme tabs settings
              See < https://yazi-rs.github.io/docs/configuration/theme#tabs>
            '';
            default = { };
          };

          mode = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme mode settings
              See < https://yazi-rs.github.io/docs/configuration/theme#mode>
            '';
            default = { };
          };

          status = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme status settings
              See < https://yazi-rs.github.io/docs/configuration/theme#status>
            '';
            default = { };
          };

          which = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme which settings
              See < https://yazi-rs.github.io/docs/configuration/theme#which>
            '';
            default = { };
          };

          confirm = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme confirm settings
              See < https://yazi-rs.github.io/docs/configuration/theme#confirm>
            '';
            default = { };
          };

          spot = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme spot settings
              See < https://yazi-rs.github.io/docs/configuration/theme#spot>
            '';
            default = { };
          };

          notify = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme notify settings
              See < https://yazi-rs.github.io/docs/configuration/theme#notify>
            '';
            default = { };
          };

          pick = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme pick settings
              See < https://yazi-rs.github.io/docs/configuration/theme#pick>
            '';
            default = { };
          };

          input = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme input settings
              See < https://yazi-rs.github.io/docs/configuration/theme#input>
            '';
            default = { };

          };

          cmp = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme cmp settings
              See < https://yazi-rs.github.io/docs/configuration/theme#cmp>
            '';
            default = { };
          };

          tasks = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme tasks settings
              See < https://yazi-rs.github.io/docs/configuration/theme#tasks>
            '';
            default = { };
          };

          help = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme help settings
              See < https://yazi-rs.github.io/docs/configuration/theme#help>
            '';
            default = { };
          };

          filetype = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme filetype settings
              See < https://yazi-rs.github.io/docs/configuration/theme#filetype>
            '';
            default = { };
          };

          icon = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Theme icon settings
              See < https://yazi-rs.github.io/docs/configuration/theme#icon>
            '';
            default = { };
          };
        };
      };
    };

    vfs = lib.mkOption {
      default = { };
      description = ''
        Content of the vfs.toml file.
        See configuration reference at <https://yazi-rs.github.io/docs/configuration/vfs>
      '';
      type = lib.types.submodule {
        freeformType = tomlFmt.type;
        options = {
          services = lib.mkOption {
            type = tomlFmt.type;
            description = ''
               Vfs settings
              See < https://yazi-rs.github.io/docs/configuration/vfs>
            '';
            default = { };
          };
        };
      };
    };

    package = lib.mkOption {
      default = { };
      description = ''
        Content of the package.toml file.
        See configuration reference at <https://yazi-rs.github.io/docs/cli/#pm>
      '';

      type = lib.types.submodule {
        freeformType = tomlFmt.type;
        options = {
          plugin = lib.mkOption {
            description = ''
              Set for plugin settings and paths.
              See configuration reference at <https://yazi-rs.github.io/docs/cli/#pm>
            '';
            default = { };
            type = lib.types.submodule {
              freeformType = tomlFmt.type;
              options.deps = lib.mkOption {
                type = lib.types.listOf tomlFmt.type;
                default = [ ];
                description = ''
                  List of plugins and dependencies.
                    See configuration reference at <https://yazi-rs.github.io/docs/cli/#pm>
                '';
              };
            };
          };
        };
      };
    };
  };

  config.package = lib.mkDefault pkgs.yazi;
  config.env = {
    YAZI_CONFIG_HOME = toString (
      pkgs.linkFarm "yazi-merged-config" (
        map
          (a: {
            inherit (a) path;
            name = a.name;
          })
          (
            let
              entry = name: path: { inherit name path; };
            in
            [
              (entry "yazi.toml" yazi)
              (entry "keymap.toml" keymap)
              (entry "theme.toml" theme)
              (entry "vfs.toml" vfs)
              (entry "package.toml" package)
            ]
          )
      )
    );
  };
  config.meta.maintainers = [ wlib.maintainers.apetrovic6 ];
}
