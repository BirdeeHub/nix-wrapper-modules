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

      "--mcp-config" = jsonFmt.generate "claude-mcp-config.json" { mcpServers = config.mcpConfig; };
      "--strict-mcp-config" = config.strictMcpConfig;
      "--settings" = jsonFmt.generate "claude-settings.json" config.settings;
    };
    meta.maintainers = [ wlib.maintainers.vinnymeller ];
  };
}
