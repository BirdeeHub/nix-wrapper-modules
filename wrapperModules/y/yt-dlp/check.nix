{ pkgs, self }:
let
  ytWrapped = self.wrappers.yt-dlp.wrap {
    inherit pkgs;
    settings.format = "worst";
  };
in
pkgs.runCommand "yt-dlp-test" { } ''
  mkdir -p $out

  # Check binary exists
  test -x "${ytWrapped}/bin/yt-dlp"

  # Check version works
  "${ytWrapped}/bin/yt-dlp" --version | grep "${ytWrapped.version}"

  # Check help works
  "${ytWrapped}/bin/yt-dlp" --help > $out/help
''
