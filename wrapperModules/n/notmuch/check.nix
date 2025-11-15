{
  pkgs,
  self,
}:

let
  notmuchWrapped =
    (self.wrapperModules.notmuch.apply {
      inherit pkgs;
      settings = {
        database.path = "/tmp/test-mail";
      };
    }).wrapper;

in
pkgs.runCommand "notmuch-test" { } ''
  "${notmuchWrapped}/bin/notmuch" --version | grep -q "notmuch"
  touch $out
''
