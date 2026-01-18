{
  config,
  wlib,
  wrapper,
  # other args from callPackage
  lib,
  lndir,
  stdenv,
  luajitPackages,
  ...
}:
finalDrv:
let
  final-packdir = "${placeholder "out"}/${config.binName}-packdir";
  start-dir = "${final-packdir}/pack/myNeovimPackages/start";
  opt-dir = "${final-packdir}/pack/myNeovimPackages/opt";
  info-plugin-path = "${start-dir}/${config.settings.info_plugin_name}";

  inherit (config)
    package
    binName
    outputs
    ;
  inherit (config.settings) info_plugin_name dont_link aliases;
  originalOutputs = wlib.getPackageOutputsSet package;
  manifestLua =
    (finalDrv.manifestLua or "")
    + "\n"
    + ''
      vim.opt.packpath:prepend(${builtins.toJSON final-packdir})
      vim.opt.runtimepath:prepend(${builtins.toJSON final-packdir})
      vim.g.nix_info_plugin_name = ${builtins.toJSON info_plugin_name}
      local configdir
      ${lib.optionalString config.settings.block_normal_config ''
        configdir = vim.fn.stdpath("config")
        vim.opt.packpath:remove(configdir)
        vim.opt.runtimepath:remove(configdir)
        vim.opt.runtimepath:remove(configdir .. "/after")
      ''}
    '';
in
finalDrv
// {
  outputs = if dont_link then [ "out" ] else outputs;
  passAsFile = [
    "manifestLua"
    "setupLua"
    "infoPluginText"
    "infoPluginInitMain"
    "buildPackDir"
    "hostLinkCmd"
    "buildCommand"
  ]
  ++ finalDrv.passAsFile or [ ];
  inherit manifestLua;
  setupLua = ''
    if package.preload[ ${builtins.toJSON info_plugin_name} ] then return end
    ${manifestLua}
    package.preload[ ${builtins.toJSON info_plugin_name} ] = function()
      return dofile(${builtins.toJSON "${info-plugin-path}/lua/${info_plugin_name}.lua"})
    end
    package.preload[ ${builtins.toJSON "${config.settings.info_plugin_name}.init_main"} ] = function()
      return dofile(${builtins.toJSON "${info-plugin-path}/lua/${info_plugin_name}/init_main.lua"})
    end
    configdir = require(${builtins.toJSON info_plugin_name}).settings.config_directory
    vim.opt.packpath:prepend(configdir)
    vim.opt.runtimepath:prepend(configdir)
    vim.opt.runtimepath:append(configdir .. "/after")
  '';
  buildCommand = ''
    mkdir -p $out/bin
    [ -d ${package}/nix-support ] && \
    mkdir -p $out/nix-support && \
    cp -r ${package}/nix-support/* $out/nix-support

  ''
  + lib.optionalString stdenv.isLinux ''
    mkdir -p $out/share/applications
    substitute ${
      lib.escapeShellArgs [
        "${package}/share/applications/nvim.desktop"
        "${placeholder "out"}/share/applications/${binName}.desktop"
        "--replace-fail"
        "Name=Neovim"
        "Name=${binName}"
        "--replace-fail"
        "TryExec=nvim"
        "TryExec=${placeholder "out"}/bin/${binName}"
        "--replace-fail"
        "Icon=nvim"
        "Icon=${package}/share/icons/hicolor/128x128/apps/nvim.png"
      ]
    }
    sed ${
      lib.escapeShellArgs [
        ''
          /^Exec=nvim/c\
          Exec=${placeholder "out"}/bin/${binName} %F''
        "${placeholder "out"}/share/applications/${binName}.desktop"
      ]
    } > ./tmp_desk && mv -f ./tmp_desk "${placeholder "out"}/share/applications/${binName}.desktop"
  ''
  + ''

    # Create symlinks for aliases
    ${lib.optionalString (aliases != [ ] && binName != "") ''
      mkdir -p $out/bin
      for alias in ${lib.concatStringsSep " " (map lib.escapeShellArg aliases)}; do
        ln -sf ${lib.escapeShellArg binName} $out/bin/$alias
      done
    ''}

    [ -e "$hostLinkCmdPath" ] && . "$hostLinkCmdPath" || runHook hostLinkCmd
    mkdir -p ${lib.escapeShellArg "${info-plugin-path}/lua/${info_plugin_name}"}
    mkdir -p ${lib.escapeShellArg opt-dir}
    [ -e "$buildPackDirPath" ] && . "$buildPackDirPath" || runHook buildPackDir
    {
      [ -e "$infoPluginTextPath" ] && cat "$infoPluginTextPath" || echo "$infoPluginText";
    } > ${lib.escapeShellArg "${info-plugin-path}/lua/${info_plugin_name}.lua"}
    {
      [ -e "$infoPluginInitMainPath" ] && cat "$infoPluginInitMainPath" || echo "$infoPluginInitMain";
    } ${
      lib.optionalString (finalDrv.hasFennel or false)
        "| ${config.package.lua.pkgs.fennel or luajitPackages.fennel}/bin/fennel --compile -"
    } > ${lib.escapeShellArg "${info-plugin-path}/lua/${info_plugin_name}/init_main.lua"}
    mkdir -p ${lib.escapeShellArg "${final-packdir}/nix-support"}
    for i in $(find -L ${lib.escapeShellArg final-packdir} -name propagated-build-inputs ); do
      cat "$i" >> ${lib.escapeShellArg "${final-packdir}/nix-support/propagated-build-inputs"}
    done

    # see:
    # https://github.com/NixOS/nixpkgs/issues/318925
    echo "Looking for lua dependencies..."
    source ${config.package.lua}/nix-support/utils.sh || true
    _addToLuaPath ${lib.escapeShellArg final-packdir} || true
    echo "propagated dependency path for plugins: $LUA_PATH"
    echo "propagated dependency cpath for plugins: $LUA_CPATH"
  ''
  + "\n"
  + wrapper
  + "\n"
  + lib.optionalString (!dont_link) ''

    ${lndir}/bin/lndir -silent "${toString package}" $out

    # Handle additional outputs by symlinking from the original package's outputs
    ${lib.concatMapStringsSep "\n" (
      output:
      if output != "out" && originalOutputs ? ${output} && originalOutputs.${output} != null then
        ''
          if [[ -n "''${${output}:-}" ]]; then
            mkdir -p ${"$" + output}
            # Only symlink from the original package's corresponding output
            ${lndir}/bin/lndir -silent "${originalOutputs.${output}}" ${"$" + output}
          fi
        ''
      else
        ""
    ) outputs}

  '';
}
