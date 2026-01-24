{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  jsonFmt = pkgs.formats.json { };
in
{
  imports = [ wlib.modules.default ];

  options = {

    agents = lib.mkOption {
      type = jsonFmt.type;
      default = { };
      description = ''
        Custom agents to add to Claude Code.

        See <https://code.claude.com/docs/en/sub-agents>
      '';
      example = {
        code-reviewer = {
          description = "Expert code reviewer. Use proactively after code changes.";
          prompt = "You are a senior code reviewer. Focus on code quality, security, and best practices.";
          tools = [
            "Read"
            "Grep"
            "Glob"
            "Bash"
          ];
          model = "sonnet";
        };
      };
    };

    mcpConfig = lib.mkOption {
      type = jsonFmt.type;
      default = { };
      description = ''
        MCP Server configuration

        Exclude the top-level `mcpServers` key from the configuration as it is automatically handled.

        See <https://code.claude.com/docs/en/mcp>
      '';
      example = {
        nixos = {
          command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
          type = "stdio";
        };
      };
    };

    pluginDirs = lib.mkOption {
      type = lib.types.listOf wlib.types.stringable;
      default = [ ];
      description = ''
        Additional directories to search for Claude Code plugins, in addition to the standard locations.

        This can be used to either load arbitrary directories of plugins, or include non-flake plugin repos managed via Nix.

        See <https://code.claude.com/docs/en/plugins>
      '';
      example = [
        "~/.custom-claude-plugins"
        "\${inputs.claude-plugins-official}/plugins/ralph-loop"
      ];
    };

    settings = lib.mkOption {
      type = jsonFmt.type;
      default = { };
      description = ''
        Claude Code settings

        These settings will override local, project, and user scoped settings.

        See <https://code.claude.com/docs/en/settings>
      '';
      example = {
        includeCoAuthoredBy = false;
        permissions = {
          deny = [
            "Bash(sudo:*)"
            "Bash(rm -rf:*)"
          ];
        };
      };
    };

    strictMcpConfig = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable the `--strict-mcp-config` flag for Claude Code.

        When enabled, Claude will only use the MCP servers provided by the `mcpConfig` option.

        If disabled, Claude may use MCP servers defined elsewhere (e.g., user or project scoped configurations).
      '';
    };

  };

  config = {
    package = lib.mkDefault pkgs.claude-code;
    unsetVar = lib.mkDefault [
      "DEV"
      # the vast majority of users will want to authenticate with their claude account and not an API key
      "ANTHROPIC_API_KEY"
    ];
    envDefault = lib.mkDefault {
      DISABLE_AUTOUPDATER = "1";
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
      DISABLE_NON_ESSENTIAL_MODEL_CALLS = "1";
      DISABLE_TELEMETRY = "1";
      DISABLE_INSTALLATION_CHECKS = "1";
    };
    flags = {
      "--agents" = builtins.toJSON config.agents;
      "--mcp-config" = jsonFmt.generate "claude-mcp-config.json" { mcpServers = config.mcpConfig; };
      "--plugin-dir" = config.pluginDirs;
      "--settings" = jsonFmt.generate "claude-settings.json" config.settings;
      "--strict-mcp-config" = config.strictMcpConfig;
    };
    meta.maintainers = [ wlib.maintainers.vinnymeller ];
  };
}
