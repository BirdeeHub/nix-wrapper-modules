{
  config,
  wlib,
  lib,
  ...
}:
let
  # implements kdl with niri semantic knowledge to convert the data-format

  # allow modifiers to be set for blocks
  leftpad = v: lib.strings.concatMapStrings (v: "  ${v}\n") (lib.strings.splitString "\n" v);
  # attrs must be quoted
  mkAttrs =
    attrs:
    if lib.isAttrs attrs then
      lib.concatMapAttrsStringSep " " (
        n: v: if builtins.isNull v then ''"${n}"'' else ''"${n}"=${toVal v}''
      ) attrs
    else
      "";
  mkBlock =
    n: v:
    let
      attrs = mkAttrs (n._attrs or null);
    in
    if v != "" then
      ''
        ${n.name or n} ${attrs} {
        ${leftpad v}
        }''
    else
      "${n.name or n} ${attrs}";
  # surround strings with qoutes
  toVal =
    v:
    if lib.isString v then
      ''"${v}"''
    else if lib.isBool v then
      (if v then "true" else "false")
    else
      toString v;
  mkKeyVal =
    k: v: "${k} ${if lib.isList v then lib.strings.concatStringsSep " " (map toVal v) else toVal v}";
  attrsToKdl =
    a:
    lib.concatMapAttrsStringSep "\n" (
      n: v:
      # turn null values into flags
      if builtins.isNull v then
        n
      else if lib.isAttrs v then
        mkBlock {
          name = n;
          _attrs = v._attrs or null;
        } (attrsToKdl (lib.removeAttrs v [ "_attrs" ]))
      else if lib.isList v && lib.all lib.isAttrs v then
        mkBlock n (lib.concatMapStringsSep "\n" attrsToKdl v)
      else
        mkKeyVal n v
    ) a;
  mkTagged =
    t: k: v:
    "${t} ${mkAttrs { ${k} = v; }}";
  mkRule =
    block: r:
    let
      matches = map (lib.concatMapAttrsStringSep "\n" (mkTagged "match")) r.matches or [ ];
      excludes = map (lib.concatMapAttrsStringSep "\n" (mkTagged "exclude")) r.excludes or [ ];
      misc = attrsToKdl (
        lib.attrsets.removeAttrs r [
          "matches"
          "excludes"
        ]
      );
    in
    mkBlock block (
      lib.strings.concatLines (
        lib.lists.flatten [
          matches
          excludes
          misc
        ]
      )
    );
  mkWorkspaces =
    w:
    map attrsToKdl (
      lib.mapAttrsToList (n: v: {
        # use the attr name as attribute for the workspace node
        workspace =
          if builtins.isNull v then
            n
          else
            {
              _attrs = {
                ${n} = null;
              };
            }
            // v;
      }) w
    );
  mkOutputs =
    w:
    map attrsToKdl (
      lib.mapAttrsToList (n: v: {
        # use the attr name as attribute for the workspace node
        output = {
          _attrs = {
            ${n} = null;
          };
        }
        // v;
      }) w
    );
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      description = ''
        Niri configuration settings.
        See <https://yalter.github.io/niri/Configuration%3A-Introduction.html>
      '';
      default = { };
      type = lib.types.submodule {
        freeformType = lib.types.attrs;
        options = {
          binds = lib.mkOption {
            default = { };
            type = lib.types.attrs;
            description = "Bindings of niri";
            example = {
              "Mod+T".spawn-sh = "alacritty";
              "Mod+J".focus-column-or-monitor-left = null;
              "Mod+N".spawn = [
                "alacritty"
                "msg"
                "create-windown"
              ];
              "Mod+0".focus-workspace = 0;
              "Mod+Escape" = {
                _attrs = {
                  allow-inhibiting = false;
                };
                toggle-keyboard-shortcuts-inhibit = null;
              };
            };
          };
          layout = lib.mkOption {
            default = { };
            type = lib.types.attrs;
            description = "Layout definitions";
            example = {
              focus-ring.off = null;
              border = {
                width = 3;
                active-color = "#f5c2e7";
                inactive-color = "#313244";
              };
            };
          };
          spawn-at-startup = lib.mkOption {
            default = [ ];
            type = lib.types.listOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
            description = ''
              List of commands to run at startup.
              The first element in a passed list will be run with the following elements as arguments
            '';
            example = [
              "hello"
              [
                "nix"
                "build"
              ]
            ];
          };
          window-rules = lib.mkOption {
            default = [ ];
            type = lib.types.listOf lib.types.attrs;
            description = "List of window rules";
            example = [
              {
                matches = [ { app-id = ".*"; } ];
                excludes = [
                  { app-id = "org.keepassxc.KeePassXC"; }
                ];
                open-focused = false;
                open-floating = false;
              }
            ];
          };
          layer-rules = lib.mkOption {
            default = [ ];
            type = lib.types.listOf lib.types.attrs;
            description = "List of layer rules";
            example = [
              {
                matches = [ { namespace = "^notifications$"; } ];
                block-out-from = "screen-capture";
                opacity = 0.8;
              }
            ];
          };
          workspaces = lib.mkOption {
            default = { };
            type = lib.types.attrsOf (lib.types.nullOr lib.types.anything);
            description = "Named workspace definitons";
            example = {
              "foo" = {
                open-on-output = "DP-3";
              };
              "bar" = null;
            };
          };
          outputs = lib.mkOption {
            default = { };
            type = lib.types.attrs;
            description = "Output configuration";
            example = {
              "DP-3" = {
                background-color = "#003300";
                hot-corners = {
                  off = null;
                };
              };
            };
          };
          extraConfig = lib.mkOption {
            default = "";
            type = lib.types.str;
            description = ''
              Escape hatch string option added to the config file for
              options that might not be representable otherwise
            '';
          };
        };
      };
    };
    "config.kdl" =
      let
        compiledConfig = lib.strings.concatLines (
          lib.lists.flatten [
            # (attrsToKdl { inherit (config.settings) binds layout; })
            (map (mkRule "window-rule") config.settings.window-rules)
            (map (mkRule "layer-rule") config.settings.layer-rules)
            (map (
              v:
              (lib.strings.concatStringsSep " " (
                lib.lists.flatten [
                  "spawn-at-startup"
                  (map (v: ''"${v}"'') (lib.flatten [ v ]))
                ]
              ))
              + "\n"
            ) config.settings.spawn-at-startup)
            (mkWorkspaces config.settings.workspaces)
            (mkOutputs config.settings.outputs)
            (attrsToKdl (
              lib.removeAttrs config.settings [
                "window-rules"
                "layer-rules"
                "spawn-at-startup"
                "workspaces"
                "outputs"
                "extraConfig"
              ]
            ))
            config.settings.extraConfig
          ]
        );
        checkedConfig = config.pkgs.writeTextFile {
          name = "niri.kdl";
          text = compiledConfig;
          checkPhase = ''
            ${lib.getExe config.package} validate -c $out
          '';
        };
      in
      lib.mkOption {
        type = wlib.types.file config.pkgs;
        default.path = checkedConfig;
        description = ''
          Configuration file for Niri.
          See <https://github.com/YaLTeR/niri/wiki/Configuration:-Introduction>
        '';
        example = ''
          input {
            keyboard {
                numlock
            }

            touchpad {
                tap
                natural-scroll
            }

            focus-follows-mouse = {
              _attrs = { max-scroll-amount = "0%"; };
            };
          }
        '';
      };
  };
  config.filesToPatch = [
    "share/applications/*.desktop"
    "share/systemd/user/niri.service"
  ];
  config.package = config.pkgs.niri;
  config.env = {
    NIRI_CONFIG = toString config."config.kdl".path;
  };
  config.meta.maintainers = [
    wlib.maintainers.patwid
  ];
  config.meta.platforms = lib.platforms.linux;
}
