{
  config,
  wlib,
  lib,
  ...
}:
let
  addGlobalVars =
    set:
    let
      listed = builtins.attrValues (builtins.mapAttrs (k: v: ''set-environment -g ${k} "${v}"'') set);
    in
    builtins.concatStringsSep "\n" listed;

  addPassthruVars =
    ptv:
    lib.optionalString (
      ptv != [ ]
    ) ''set-option -ga update-environment "${builtins.concatStringsSep " " ptv}"'';

  configPlugins =
    plugins:
    (
      let
        pluginName = p: if lib.types.package.check p then p.pname else p.plugin.pname;
        pluginRTP = p: if lib.types.package.check p then p.rtp else p.plugin.rtp;
        pluginConfigPre = p: if lib.types.package.check p then "" else p.configBefore or "";
        pluginConfigPost = p: if lib.types.package.check p then "" else p.configAfter or "";
      in
      if plugins == [ ] || !(builtins.isList plugins) then
        ""
      else
        ''
          # ============================================== #
          ${
            (lib.concatMapStringsSep "\n\n" (p: ''
              # ${pluginName p}
              # ---------------------
              ${pluginConfigPre p}
              run-shell ${pluginRTP p}
              ${pluginConfigPost p}
              # ---------------------
            '') plugins)
          }
          # ============================================== #
        ''
    );
  tmux_bool_conv = v: if v then "on" else "off";
in
{
  imports = [ wlib.modules.default ];
  options = {
    sourceSensible = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start with defaults from tmuxPlugins.sensible";
    };
    secureSocket = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Store tmux socket under {file}`/run`, which is more
        secure than {file}`/tmp`, but as a downside it doesn't
        survive user logout.
      '';
    };
    configBefore = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        configuration to run before all tmux plugins are sourced
      '';
    };
    configAfter = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        configuration to run after all tmux plugins are sourced
      '';
    };
    plugins = lib.mkOption {
      default = [ ];
      description = "List of tmux plugins to source.";
      type = lib.types.listOf (
        lib.types.oneOf [
          lib.types.package
          (lib.types.submodule {
            options = {
              plugin = lib.mkOption {
                type = lib.types.package;
                description = ''
                  the tmux plugin to source
                '';
              };
              configBefore = lib.mkOption {
                type = lib.types.lines;
                default = "";
                description = ''
                  configuration to run before the plugin is sourced
                '';
              };
              configAfter = lib.mkOption {
                type = lib.types.lines;
                default = "";
                description = ''
                  configuration to run after the plugin is sourced
                '';
              };
            };
          })
        ]
      );
    };
    prefix = lib.mkOption {
      type = lib.types.str;
      default = "C-b";
      description = "Set the prefix key for tmux.";
    };
    updateEnvironment = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "TERM"
        "TERM_PROGRAM"
      ];
      description = ''
        List of environment variables to update when the tmux session is created.
        `set-option -ga update-environment <your list of variables>`
      '';
    };
    setEnvironment = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.str
          lib.types.package
        ]
      );
      default = { };
      description = ''
        attrset of environment variables to set when the tmux session is created.
        `set-environment -g ''${key} "''${value}"`
      '';
    };
    displayPanesColour = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = "Value for `set -g display-panes-colour`.";
    };
    terminal = lib.mkOption {
      type = lib.types.str;
      default = "screen";
      description = "Value for `set -g default-terminal`.";
    };
    terminalOverrides = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Value for `set -ga terminal-overrides`.";
    };
    baseIndex = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Value for `set -g base-index`.";
    };
    paneBaseIndex = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Value for `setw -g pane-base-index`.";
    };
    mouse = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable mouse mode.";
    };
    aggressiveResize = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Value for `setw -g aggressive-resize`.";
    };
    clock24 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "use 24 hour clock instead of 12 hour clock";
    };
    escapeTime = lib.mkOption {
      type = lib.types.int;
      default = 500;
      description = "Value for `set -s escape-time`.";
    };
    historyLimit = lib.mkOption {
      type = lib.types.int;
      default = 2000;
      description = "Value for `set -g history-limit`.";
    };
    allowPassthrough = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Value for `set -gq allow-passthrough`.";
    };
    visualActivity = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Value for `set -g visual-activity`.";
    };
    vimVisualKeys = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "v and y keybindings for copy-mode-vi.";
    };
    disableConfirmationPrompt = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "disable the confirmation prompt for kill-window and kill-pane keybindings.";
    };
    shell = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "set -g default-shell";
    };
    statusKeys = lib.mkOption {
      type = lib.types.str;
      default = "emacs";
      description = "Value for `set -g status-keys`.";
    };
    modeKeys = lib.mkOption {
      type = lib.types.str;
      default = "emacs";
      description = "Value for `set -g mode-keys`.";
    };
  };
  config = {
    flags = {
      "-f" = "${config.pkgs.writeText "tmux.conf" # tmux
        ''
          ${lib.optionalString config.sourceSensible ''
            # ============================================= #
            # Start with defaults from the Sensible plugin  #
            # --------------------------------------------- #
            run-shell ${config.pkgs.tmuxPlugins.sensible.rtp}
            # ============================================= #
          ''}
          unbind C-b
          set-option -g prefix ${config.prefix}
          set -g prefix ${config.prefix}
          bind -N "Send the prefix key through to the application" \
            ${config.prefix} send-prefix

          set -g display-panes-colour ${config.displayPanesColour}
          set -g default-terminal ${config.terminal}
          ${lib.optionalString (config.shell != null) ''
            set  -g default-shell "${config.shell}"
          ''}
          ${addPassthruVars config.updateEnvironment}
          ${addGlobalVars config.setEnvironment}
          ${lib.optionalString (config.terminalOverrides != null) ''
            set -ga terminal-overrides "${config.terminalOverrides}"
          ''}

          set -g base-index ${toString config.baseIndex}
          setw -g pane-base-index ${toString config.paneBaseIndex}

          set -g mouse ${tmux_bool_conv config.mouse}
          setw -g aggressive-resize ${tmux_bool_conv config.aggressiveResize}
          setw -g clock-mode-style ${if config.clock24 then "24" else "12"}
          set -s escape-time ${toString config.escapeTime}
          set -g history-limit ${toString config.historyLimit}
          set -gq allow-passthrough ${tmux_bool_conv config.allowPassthrough}
          set -g visual-activity ${tmux_bool_conv config.visualActivity}

          set -g status-keys ${config.statusKeys}
          set -g mode-keys   ${config.modeKeys}

          ${lib.optionalString config.vimVisualKeys ''
            bind-key -T copy-mode-vi 'v' send -X begin-selection
            bind-key -T copy-mode-vi 'y' send -X copy-selection-and-cancel
          ''}

          ${lib.optionalString config.disableConfirmationPrompt ''
            bind-key -N "Kill the current window" & kill-window
            bind-key -N "Kill the current pane" x kill-pane
          ''}

          ${config.configBefore}

          ${configPlugins config.plugins}

          ${config.configAfter}
        ''
      }";
    };
    runShell = lib.mkIf config.secureSocket [
      ''export TMUX_TMPDIR=''${TMUX_TMPDIR:-''${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}}''
    ];
    package = config.pkgs.tmux;
    meta.maintainers = [ lib.maintainers.birdee ];
  };
}
