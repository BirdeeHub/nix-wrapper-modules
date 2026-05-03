{
  pkgs,
  self,
  tlib,
  writeText,
  ...
}:

let
  inherit (tlib)
    fileContains
    isFile
    isDirectory
    notIsFile
    notIsDirectory
    test
    ;
  wm = self.wrappers.oh-my-posh;
in
test { wrapper = "oh-my-posh"; } {

  "wrapper should output correct version" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
      };
    in
    ''
      "${wrapper}/bin/oh-my-posh" --version |
      grep -q "${wrapper.version}"
    '';

  "If config is provided then config.json is properly set up" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        theme = "jandedobbeleer";
      };
      configFile = "${wrapper}/config.json";
    in
    [
      (isFile configFile)
      (fileContains "${wrapper}/bin/oh-my-posh" "--config.*${configFile}")
    ];

  "If no config is provided then no config.json is set up" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
      };
      configFile = "${wrapper}/config.json";
    in
    notIsFile configFile;

  "config chains" =
    let
      baseWrapper = wm.wrap {
        inherit pkgs;
        theme = [
          "aliens"
          "agnoster"
        ];
        settings.foo = "foo";
        configFile = writeText "file-config.yaml" "bar: bar";
      };
      nixStoreFile = name: "/nix/store/[[:alnum:]]{32}-.*${name}";
      extendsPattern = path: ''"extends": "${path}"'';
    in
    {
      "theme > file > settings (default order)" =
        let
          wrapper = baseWrapper;
          configChainDir = "${wrapper}/config-chain";

          nixSettingsFile = "${configChainDir}/settings.json";
          fileSettingsFile = "${configChainDir}/file-config.json";
          agnosterFile = "${configChainDir}/agnoster.omp.json";
        in
        [
          "[[ -h ${wrapper}/config.json ]]"
          "[[ $(readlink -f ${wrapper}/config.json) == ${nixSettingsFile} ]]"
          (fileContains nixSettingsFile (extendsPattern fileSettingsFile))
          (fileContains fileSettingsFile (extendsPattern agnosterFile))
          (fileContains agnosterFile (extendsPattern (nixStoreFile "aliens.omp.json")))
        ];

      "file > theme > settings" =
        let
          wrapper = baseWrapper.wrap {
            order = [
              "file"
              "theme"
              "settings"
            ];
          };
          configChainDir = "${wrapper}/config-chain";

          nixSettingsFile = "${configChainDir}/settings.json";
          agnosterFile = "${configChainDir}/agnoster.omp.json";
          aliensFile = "${configChainDir}/aliens.omp.json";
        in
        [
          "[[ -h ${wrapper}/config.json ]]"
          "[[ $(readlink -f ${wrapper}/config.json) == ${nixSettingsFile} ]]"
          (fileContains nixSettingsFile (extendsPattern agnosterFile))
          (fileContains agnosterFile (extendsPattern aliensFile))
          (fileContains aliensFile (extendsPattern (nixStoreFile "file-config.json")))
        ];

      "file > settings > theme" =
        let
          wrapper = baseWrapper.wrap {
            order = [
              "file"
              "settings"
              "theme"
            ];
          };
          configChainDir = "${wrapper}/config-chain";

          agnosterFile = "${configChainDir}/agnoster.omp.json";
          aliensFile = "${configChainDir}/aliens.omp.json";
          nixSettingsFile = "${configChainDir}/settings.json";
        in
        [
          "[[ -h ${wrapper}/config.json ]]"
          "[[ $(readlink -f ${wrapper}/config.json) == ${agnosterFile} ]]"
          (fileContains agnosterFile (extendsPattern aliensFile))
          (fileContains aliensFile (extendsPattern nixSettingsFile))
          (fileContains nixSettingsFile (extendsPattern (nixStoreFile "file-config.json")))
        ];

      "settings > theme > file" =
        let
          wrapper = baseWrapper.wrap {
            order = [
              "settings"
              "theme"
              "file"
            ];
          };
          configChainDir = "${wrapper}/config-chain";

          fileSettingsFile = "${configChainDir}/file-config.json";
          agnosterFile = "${configChainDir}/agnoster.omp.json";
          aliensFile = "${configChainDir}/aliens.omp.json";
        in
        [
          "[[ -h ${wrapper}/config.json ]]"
          "[[ $(readlink -f ${wrapper}/config.json) == ${fileSettingsFile} ]]"
          (fileContains fileSettingsFile (extendsPattern agnosterFile))
          (fileContains agnosterFile (extendsPattern aliensFile))
          (fileContains aliensFile (extendsPattern (nixStoreFile "settings.json")))
        ];

      "theme > settings > file" =
        let
          wrapper = baseWrapper.wrap {
            order = [
              "theme"
              "settings"
              "file"
            ];
          };
          configChainDir = "${wrapper}/config-chain";

          fileSettingsFile = "${configChainDir}/file-config.json";
          nixSettingsFile = "${configChainDir}/settings.json";
          agnosterFile = "${configChainDir}/agnoster.omp.json";
        in
        [
          "[[ -h ${wrapper}/config.json ]]"
          "[[ $(readlink -f ${wrapper}/config.json) == ${fileSettingsFile} ]]"
          (fileContains fileSettingsFile (extendsPattern nixSettingsFile))
          (fileContains nixSettingsFile (extendsPattern agnosterFile))
          (fileContains agnosterFile (extendsPattern (nixStoreFile "aliens.omp.json")))
        ];

      "settings > file > theme" =
        let
          wrapper = baseWrapper.wrap {
            order = [
              "settings"
              "file"
              "theme"
            ];
          };
          configChainDir = "${wrapper}/config-chain";

          agnosterFile = "${configChainDir}/agnoster.omp.json";
          aliensFile = "${configChainDir}/aliens.omp.json";
          fileSettingsFile = "${configChainDir}/file-config.json";
        in
        [
          "[[ -h ${wrapper}/config.json ]]"
          "[[ $(readlink -f ${wrapper}/config.json) == ${agnosterFile} ]]"
          (fileContains agnosterFile (extendsPattern aliensFile))
          (fileContains aliensFile (extendsPattern fileSettingsFile))
          (fileContains fileSettingsFile (extendsPattern (nixStoreFile "settings.json")))
        ];
    };

  "config file formats" =
    let
      key = "dummy_key";
      value = "dummy_value";
    in
    {
      "json configFile is loaded" =
        let
          wrapper = wm.wrap {
            inherit pkgs;
            configFile = writeText "config.json" ''{"${key}": "${value}"}'';
          };
          generatedConfig = "${wrapper}/config.json";
        in
        [
          (isFile generatedConfig)
          (fileContains generatedConfig key)
          (fileContains generatedConfig value)
        ];

      "yaml configFile is loaded" =
        let
          wrapper = wm.wrap {
            inherit pkgs;
            configFile = writeText "config.yaml" "${key}: ${value}";
          };
          generatedConfig = "${wrapper}/config.json";
        in
        [
          (isFile generatedConfig)
          (fileContains generatedConfig key)
          (fileContains generatedConfig value)
        ];

      "toml configFile is loaded" =
        let
          wrapper = wm.wrap {
            inherit pkgs;
            configFile = writeText "config.toml" ''${key} = "${value}"'';
          };
          generatedConfig = "${wrapper}/config.json";
        in
        [
          (isFile generatedConfig)
          (fileContains generatedConfig key)
          (fileContains generatedConfig value)
        ];
    };

  "explicit `extends` in settings breaks the config chain" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        theme = [
          "aliens"
          "agnoster"
        ];
        settings.extends = "foo";
      };
      configChainDir = "${wrapper}/config-chain";
    in
    [
      (isFile "${configChainDir}/settings.json")
      (notIsFile "${configChainDir}/agnoster.omp.json")
      (notIsFile "${configChainDir}/aliens.omp.json")
    ];

  "If a single config is provided then no config-chain dir is created" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        settings.extends = "foo";
      };
    in
    [
      (isFile "${wrapper}/config.json")
      (notIsDirectory "${wrapper}/config-chain")
    ];

  "extending segments works as expected" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        configFile = writeText "config.yaml" ''
          blocks:
            - type: prompt
              alignment: left
              segments:
                - type: text
                  style: plain
                  template: "[b1s1]"
                - type: text
                  style: plain
                  template: "[b1s2]"
            - type: prompt
              alignment: right
              segments:
                - type: text
                  style: plain
                  template: "[b2s1]"
                - type: text
                  style: plain
                  template: "[b2s2]"
                  alias: foo
        '';
        settings.blocks = [
          {
            type = "prompt";
            alignment = "right";
            segments = [
              {
                type = "text";
                style = "plain";
                alias = "foo";
                template = "foo";
              }
            ];
          }
        ];
      };
    in
    # '[b2s2]' should be overridden with 'foo'
    [
      "${wrapper}/bin/oh-my-posh print primary | grep -Fq  '[b1s1]'"
      "${wrapper}/bin/oh-my-posh print primary | grep -Fq  '[b1s2]'"
      "${wrapper}/bin/oh-my-posh print primary | grep -Fq  '[b2s1]'"
      "${wrapper}/bin/oh-my-posh print primary | grep -Fqv '[b2s2]'"
      "${wrapper}/bin/oh-my-posh print primary | grep -Fq  'foo'"
    ];
}
