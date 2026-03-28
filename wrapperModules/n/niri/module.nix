{
  config,
  pkgs,
  wlib,
  lib,
  ...
}:
let
  # deprecates `{ _attrs = ??; ... }` and `null` to `_: { props = ??; content = ...; }` and `_: {}` respectively
  # remove on June 1, 2026
  convertAndWarn =
    let
      endOfWarningMessage = "\n" + ''
        Warning will be removed on June 1, 2026,
        but you can remove this deprecation layer ahead of time
        after fixing your configuration by setting `v2-settings = true`.
      '';
      recurse =
        path: v:
        if builtins.isAttrs v then
          let
            hasAttrs = v ? _attrs;
            rest = lib.removeAttrs v [ "_attrs" ];
            processedRest = lib.mapAttrs (n: val: recurse (path ++ [ n ]) val) rest;
          in
          if hasAttrs then
            lib.warn
              (
                "wrapperModules.niri: Deprecated `{ _attrs = ??; ... }` at ${lib.concatStringsSep "." path}. Use `_: { props = ??; content = ...; }` instead."
                + endOfWarningMessage
              )
              (_: {
                props = recurse (path ++ [ "_attrs" ]) v._attrs;
                content = processedRest;
              })
          else
            processedRest
        else if builtins.isList v && builtins.all builtins.isAttrs v then
          map (i: recurse (path ++ [ "[${toString i}]" ]) i) v
        else if v == null then
          lib.warn (
            "wrapperModules.niri: Deprecated `null` at ${lib.concatStringsSep "." path}. Use `_: {}` instead."
            + endOfWarningMessage
          ) (_: { })
        else
          v;
    in
    if config.v2-settings then v: v else v: recurse [ ] v;

  mkRule = # "window-rules" "layer-rules"
    node: r:
    let
      matches = map (m: { match = _: { props = m; }; }) (r.matches or [ ]);
      excludes = map (m: { exclude = _: { props = m; }; }) (r.excludes or [ ]);
      other = lib.mapAttrsToList (n: v: { ${n} = v; }) (
        lib.attrsets.removeAttrs r [
          "matches"
          "excludes"
        ]
      );
    in
    {
      ${node} = matches ++ excludes ++ other;
    };
  attrAsArg = # "workspace" "output"
    node:
    lib.mapAttrsToList (
      n: v: {
        # use the attr name as arg for the named node
        ${node} =
          s:
          if lib.isFunction v then
            let
              res = v s;
            in
            res
            // {
              props =
                if res ? props then
                  if builtins.isAttrs res.props then
                    [
                      n
                      res.props
                    ]
                  else if builtins.isList res.props then
                    [ n ] ++ res.props
                  else
                    n
                else
                  n;
            }
          else if builtins.isAttrs v then
            {
              content = v;
              props = n;
            }
          else
            { props = n; };
      }
    );
in
{
  imports = [ wlib.modules.default ];

  options = {
    v2-settings = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        If you have converted your configuration from the old version of the niri module's kdl translation to the new one already,
        you may set this to true to stop it from checking for the old version.

        On July 1, 2026, when that version is removed, this option will warn that it no longer has any effect.

        The change was as follows:

        For doing

        ```kdl
        node "some" "args" "y"=100 {
        }
        ```

        `{ _attrs = ??; ... }` was changed to `_: { props = ??; content = ...; }`

        And in the context of declaring a node which is just a name with no children or props:

        `null` was changed to `_: {}` because `null` is an actual value you may want to provide.

        Functions were the only type of value we could not translate.

        The argument to the function is provided by calling the function with `lib.fix`.
      '';
    };
    settings = lib.mkOption {
      description = ''
        Niri configuration settings.
        See <https://yalter.github.io/niri/Configuration%3A-Introduction.html>

        This is a freeform submodule. If you do not see your option listed,
        try setting it using the format specified by `wlib.toKdl`
      '';
      default = { };
      type = lib.types.submodule {
        freeformType = lib.types.attrs;
        options = {
          binds = lib.mkOption {
            default = { };
            type = lib.types.attrs;
            description = "Bindings of niri";
            apply = convertAndWarn;
            example = {
              "Mod+T".spawn-sh = "alacritty";
              "Mod+J".focus-column-or-monitor-left = _: { };
              "Mod+N".spawn = [
                "alacritty"
                "msg"
                "create-windown"
              ];
              "Mod+0".focus-workspace = 0;
              "Mod+Escape" = _: {
                props.allow-inhibiting = false;
                content.toggle-keyboard-shortcuts-inhibit = _: { };
              };
            };
          };
          layout = lib.mkOption {
            default = { };
            type = lib.types.attrs;
            description = "Layout definitions";
            apply = convertAndWarn;
            example = {
              focus-ring.off = _: { };
              border = {
                width = 3;
                active-color = "#f5c2e7";
                inactive-color = "#313244";
              };
              preset-column-widths = [
                { proportion = 0.5; }
                { proportion = 0.666667; }
              ];
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
            apply = convertAndWarn;
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
            apply = convertAndWarn;
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
            description = "Named workspace definitions";
            apply = convertAndWarn;
            example = {
              "foo" = {
                open-on-output = "DP-3";
              };
              "bar" = _: { };
            };
          };
          outputs = lib.mkOption {
            default = { };
            type = lib.types.attrs;
            description = "Output configuration";
            apply = convertAndWarn;
            example = {
              "DP-3" = {
                background-color = "#003300";
                hot-corners = {
                  off = _: { };
                };
              };
            };
          };
          extraConfig = lib.mkOption {
            default = "";
            type = lib.types.str;
            description = ''
              Escape hatch string option added to the config file for
              options that might not be representable otherwise,
              due to `config.settings` in this module being required to be an attribute set.
            '';
          };
        };
      };
    };
    "config.kdl" = lib.mkOption {
      type = wlib.types.file pkgs;
      default.path = config.constructFiles.generatedConfig.path;
      default.content = "";
      description = ''
        Configuration file for Niri.
        See <https://github.com/YaLTeR/niri/wiki/Configuration:-Introduction>

        If `config."config.kdl".content is non-empty, its content will be used instead of the generated
        config from `config.settings` in the generated config file in the derivation.

        You may also set `config."config.kdl".path` to your own path.

        This will still allow the generated config to be created from `config.settings`

        You could use the include feature to include it.
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

          focus-follows-mouse "max-scroll-amount"="0%" {
          }
        }
      '';
    };
  };
  config.filesToPatch = [
    "share/applications/*.desktop"
    "share/systemd/user/niri.service"
  ];
  # NOTE: gives users a nice error message about invalid configs, with actual knowledge of niri's config format
  config.drv.installPhase = ''
    runHook preInstall
    ${lib.getExe config.package} validate -c ${config.constructFiles.generatedConfig.path}
    runHook postInstall
  '';
  config.package = pkgs.niri;
  config.env.NIRI_CONFIG = config."config.kdl".path;
  config.constructFiles.generatedConfig = {
    relPath = "${config.binName}-config.kdl";
    content =
      if config."config.kdl".content or "" != "" then
        config."config.kdl".content
      else
        wlib.toKdl (
          builtins.concatLists [
            (map (mkRule "window-rule") config.settings.window-rules)
            (map (mkRule "layer-rule") config.settings.layer-rules)
            (map (v: { spawn-at-startup = _: { props = v; }; }) config.settings.spawn-at-startup)
            (attrAsArg "workspace" config.settings.workspaces)
            (attrAsArg "output" config.settings.outputs)
            [
              (convertAndWarn (
                lib.removeAttrs config.settings [
                  "window-rules"
                  "layer-rules"
                  "spawn-at-startup"
                  "workspaces"
                  "outputs"
                  "extraConfig"
                ]
              ))
            ]
          ]
        )
        + "\n"
        + config.settings.extraConfig;
  };
  config.meta.maintainers = [
    wlib.maintainers.patwid
  ];
  config.meta.platforms = lib.platforms.linux;
  config.passthru.providedSessions = pkgs.niri.passthru.providedSessions;
}
