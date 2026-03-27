{
  pkgs,
  self,
}:
let
  emacsWrapped =
    (self.wrappers.emacs.apply {
      inherit pkgs;
      emacsPackages =
        epkgs:
        let
          m = epkgs.melpaPackages;
        in
        [
          m.evil
          m.ivy
        ];
      configFile = ''
        (setq inhibit-startup-message t)
        (set-fringe-mode 10)
      '';
    }).wrapper;
in
pkgs.runCommand "emacs-test" { } ''
  "${emacsWrapped}/bin/emacs" --help | grep -q "Usage"
  grep -q --no-ignore-case -- "--init-directory" "${emacsWrapped}/bin/emacs"
  touch $out
''
