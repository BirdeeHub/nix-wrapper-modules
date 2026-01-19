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
  claude="${claudeCodeWrapped}/bin/claude"
  if ! grep -q -- "--strict-mcp-config" "$claude"; then
    echo "FAIL: --strict-mcp-config flag not found in wrapped claude binary"
    cat "$claude"
    exit 1
  fi
  touch $out
''
