{
  pkgs,
  self,
}:

let
  vimWrappedDefault = self.wrappers.vim.wrap { inherit pkgs; };

  vimWrapped = vimWrappedDefault.wrap (
    { pkgs, ... }:
    {
      plugins = [
        pkgs.vimPlugins.vim-sleuth
      ];

      optionalPlugins = [
        pkgs.vimPlugins.vim-surround
      ];

      vimrc = ''
        set tabstop=17
      '';
    }
  );

in
pkgs.runCommand "vim-test" { } ''
  res=$('${vimWrappedDefault}/bin/vim' -es +':redir >> /dev/stdout' +'echo g:loaded_sensible' +'q')

  if ! echo "''${res}" | grep -q 'yes'; then
    echo 'Vim does not load default plugins.'
    touch $out
    exit 1
  fi

  res=$('${vimWrapped}/bin/vim' -es +':redir >> /dev/stdout' +'scriptnames' +'q')

  if ! echo "''${res}" | grep -q 'sleuth.vim'; then
    echo 'Vim does not load plugins.'
    touch $out
    exit 1
  fi

  if ! echo "''${res}" | grep -qv 'surround.vim'; then
    echo 'Vim loads optional plugins on startup.'
    touch $out
    exit 1
  fi

  res=$('${vimWrapped}/bin/vim' -es +':redir >> /dev/stdout' +'packadd vim-surround' +'scriptnames' +'q')

  if ! echo "''${res}" | grep -q 'surround.vim'; then
    echo 'Vim does not load optional plugins.'
    touch $out
    exit 1
  fi

  res=$('${vimWrapped}/bin/vim' -es +':redir >> /dev/stdout' +'set tabstop?' +'scriptnames' +'q')

  if ! echo "''${res}" | grep -q 'tabstop=17'; then
    echo 'Vim does not apply configuration.'
    touch $out
    exit 1
  fi

  touch $out
''
