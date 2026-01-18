{
  self,
  pkgs,
  ...
}:
let
  runpkg = pkg: "${pkg}/bin/${pkg.configuration.binName} --headless";
  nvimpkg = self.wrappedModules.neovim.wrap [
    { inherit pkgs; }
    (
      {
        pkgs,
        lib,
        wlib,
        config,
        ...
      }:
      {
        config.specs.EXIT_TEST = {
          data = null;
          type = "lua";
          # should already be after and shouldn't be reordered to be before
          # the others, however, are ordered to be before INIT_MAIN via specMods setting
          # after = [ "INIT_MAIN" ];
          config = ''
            my_assert(vim.g.main_init_test_ran == 1, "config directory not loaded correctly")
            os.exit(0)
          '';
        };
        config.specs.SETUP_ASSERTS = {
          data = null;
          type = "lua";
          config = ''
            _G.my_assert = function(cond, ...)
              if cond then
                return ...
              else
                print("❌")
                print(...)
                os.exit(1)
              end
            end
            _G.assert_call = function(...) return my_assert(pcall(...)) end
          '';
        };
        config.info.infotest = lib.generators.mkLuaInline "vim.fn.stdpath('config')";
        config.specs.infotest = {
          data = null;
          type = "lua";
          info.infotest = lib.generators.mkLuaInline "vim.fn.stdpath('config')";
          config = ''
            local info = ...
            my_assert(vim.fn.stdpath('config') == info.infotest, "integrated info fetch did not work")
            my_assert(
              vim.fn.stdpath('config') == assert_call(
                assert_call(require, vim.g.nix_info_plugin_name),
                nil,
                "info",
                "infotest"
              ),
              "nix info plugin fetch function did not work"
            )
          '';
        };
        config.specs.fnltest = {
          data = pkgs.vimPlugins.mini-nvim;
          type = "fnl";
          info.infotest = lib.generators.mkLuaInline "vim.fn.stdpath('config')";
          config = ''
            (local (info) ...)
            (_G.my_assert (= info.infotest (vim.fn.stdpath "config")) "integrated info fetch did not work for fennel")
            (_G.assert_call require "mini.base16")
          '';
        };
        config.specs.vimtest = {
          data = null;
          type = "vim";
          info.infotest = lib.generators.mkLuaInline "vim.fn.stdpath('config')";
          config = ''
            let info = a:000[0]
            " Compare infotest field to stdpath('config')
            if get(info, 'infotest', ' ') == stdpath('config')
              echo "✅ match " . get(info, 'infotest', ' ')
            else
              echo "❌ mismatch: " . get(info, 'infotest', ' ')
              cquit
            endif
          '';
        };
        config.settings.config_directory = ./testconfig;
        config.specMods =
          { name, ... }:
          {
            before = [ "EXIT_TEST" ] ++ lib.optional (name != "EXIT_TEST") "INIT_MAIN";
            after = lib.mkIf (name != "EXIT_TEST") [ "SETUP_ASSERTS" ];
          };
      }
    )
  ];

  shellAndDontLink = nvimpkg.wrap {
    config.wrapperImplementation = "shell";
    config.settings.dont_link = true;
  };
in
pkgs.runCommand "neovim-test" { } ''
  export HOME=$(mktemp -d)
  ${runpkg nvimpkg}
  ${runpkg shellAndDontLink}
  touch "$out"
''
