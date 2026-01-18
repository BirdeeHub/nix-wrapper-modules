{
  pkgs,
  self,
}:
let
  claudeCodeWrapped = self.wrappedModules.claude-code.wrap {
    inherit pkgs;

    mcpConfig = {
      nixos = {
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        type = "stdio";
      };
    };
    strictMcpConfig = true;
  };
in
pkgs.runCommand "claude-code-test" { } ''
  "${claudeCodeWrapped}/bin/claude" mcp get nixos
  touch $out
''
