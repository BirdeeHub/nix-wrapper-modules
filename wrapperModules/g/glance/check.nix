{
  pkgs,
  self,
  ...
}:
let
  glanceWrapped = self.wrappers.glance.wrap {
    inherit pkgs;
    settings = {
      server.port = 5678;
      pages = [
        {
          name = "Home";
          columns = [
            {
              size = "full";
              widgets = [
                { type = "calendar"; }
                {
                  type = "weather";
                  location = "London, United Kingdom";
                }
              ];
            }
          ];
        }
      ];
    };
  };
in
pkgs.runCommand "glance-test" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
  "${glanceWrapped}/bin/glance" config:validate

  config=$("${glanceWrapped}/bin/glance" config:print)
  test "$(echo "$config" | yq '.server.port')" = "5678"
  test "$(echo "$config" | yq '.pages[0].name')" = "Home"
  test "$(echo "$config" | yq '.pages[0].columns[0].size')" = "full"
  test "$(echo "$config" | yq '.pages[0].columns[0].widgets[0].type')" = "calendar"
  test "$(echo "$config" | yq '.pages[0].columns[0].widgets[1].type')" = "weather"
  test "$(echo "$config" | yq '.pages[0].columns[0].widgets[1].location')" = "London, United Kingdom"

  touch $out
''
