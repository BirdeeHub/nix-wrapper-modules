{
  pkgs,
  self,
}:
let
  lib = pkgs.lib;
  module.options = {
    fileWithContent = lib.mkOption {
      type = self.lib.types.file pkgs;
      default.content = "test content";
    };
    fileWithPathOverride = lib.mkOption {
      type = self.lib.types.file pkgs;
      default.content = "should be ignored";
      default.path = "/etc/hosts";
    };
    fileWithStorePathOverride = lib.mkOption {
      type = self.lib.types.file pkgs;
      default.content = "should also be ignored";
      default.path = pkgs.writeText "custom-file" "custom content";
    };
  };
  evaledModule = pkgs.lib.evalModules { modules = [ module ]; };
  evaledModuleWithOverride = lib.evalModules {
    modules = [
      module
      { fileWithContent.content = "test content2"; }
      { fileWithPathOverride.path = "/etc/hosts2"; }
      {
        fileWithStorePathOverride.path = pkgs.writeText "custom-file2" "custom content2";
      }
    ];
  };
  evaledModuleWithForce = lib.evalModules {
    modules = [
      module
      { fileWithContent.content = lib.mkForce "test content3"; }
      { fileWithPathOverride.path = lib.mkForce "/etc/hosts3"; }
      {
        fileWithStorePathOverride.path = lib.mkForce (pkgs.writeText "custom-file3" "custom content3");
      }
    ];
  };
  evaledModuleWithDefault = lib.evalModules {
    modules = [
      module
      { fileWithContent.content = lib.mkDefault "test content4"; }
      { fileWithPathOverride.path = lib.mkDefault "/etc/hosts4"; }
      {
        fileWithStorePathOverride.path = lib.mkDefault (pkgs.writeText "custom-file4" "custom content4");
      }
    ];
  };
  evaledModuleWithOptionDefault = lib.evalModules {
    modules = [
      module
      { fileWithContent.content = lib.mkOptionDefault "test content5"; }
      # those two cause `content was accessed but no value defined` errors
      # { fileWithPathOverride.path = lib.mkOptionDefault "/etc/hosts5"; }
      # {
      #   fileWithStorePathOverride.path = lib.mkOptionDefault (
      #     pkgs.writeText "custom-file5" "custom content5"
      #   );
      # }
    ];
  };

in
pkgs.runCommand "types-file-test" { } ''
  echo "Testing types.file..."
  # Check fileWithContent
  file1="${evaledModule.config.fileWithContent.path}"
  if [ ! -f "$file1" ]; then
    echo "FAIL: fileWithContent does not exist"
    exit 1
  fi
  content1=$(cat "$file1")
  if [ "$content1" != "test content" ]; then
    echo "FAIL: fileWithContent has incorrect content: $content1"
    exit 1
  fi
  # Check fileWithPathOverride
  file2="${evaledModule.config.fileWithPathOverride.path}"
  if [ "$file2" != "/etc/hosts" ]; then
    echo "FAIL: fileWithPathOverride path is incorrect: $file2"
    exit 1
  fi
  # Check fileWithStorePathOverride
  file3="${evaledModule.config.fileWithStorePathOverride.path}"
  expectedStorePath="${pkgs.writeText "custom-file" "custom content"}"
  if [ "$file3" != "$expectedStorePath" ]; then
    echo "FAIL: fileWithStorePathOverride store path is incorrect: $file3"
    exit 1
  fi

  file4="${evaledModuleWithOverride.config.fileWithContent.path}"
  if [ ! -f "$file4" ]; then
    echo "FAIL: evaledModuleWithOverride.fileWithContent does not exist"
    exit 1
  fi
  content4=$(cat "$file4")
  if [ "$content4" != "test content2" ]; then
    echo "FAIL: evaledModuleWithOverride.fileWithContent has incorrect content: $content4"
    exit 1
  fi
  # Check fileWithPathOverride
  file5="${evaledModuleWithOverride.config.fileWithPathOverride.path}"
  if [ "$file5" != "/etc/hosts2" ]; then
    echo "FAIL: evaledModuleWithOverride.fileWithPathOverride path is incorrect: $file5"
    exit 1
  fi
  # Check fileWithStorePathOverride
  file6="${evaledModuleWithOverride.config.fileWithStorePathOverride.path}"
  expectedStorePath="${pkgs.writeText "custom-file2" "custom content2"}"
  if [ "$file6" != "$expectedStorePath" ]; then
    echo "FAIL: evaledModuleWithOverride.fileWithStorePathOverride store path is incorrect: $file6"
    exit 1
  fi

  file7="${evaledModuleWithForce.config.fileWithContent.path}"
  if [ ! -f "$file7" ]; then
    echo "FAIL: evaledModuleWithForce.fileWithContent does not exist"
    exit 1
  fi
  content7=$(cat "$file7")
  if [ "$content7" != "test content3" ]; then
    echo "FAIL: evaledModuleWithForce.fileWithContent has incorrect content: $content7"
    exit 1
  fi
  # Check fileWithPathOverride
  file8="${evaledModuleWithForce.config.fileWithPathOverride.path}"
  if [ "$file8" != "/etc/hosts3" ]; then
    echo "FAIL: evaledModuleWithForce.fileWithPathOverride path is incorrect: $file8"
    exit 1
  fi
  # Check fileWithStorePathOverride
  file9="${evaledModuleWithForce.config.fileWithStorePathOverride.path}"
  expectedStorePath="${pkgs.writeText "custom-file3" "custom content3"}"
  if [ "$file9" != "$expectedStorePath" ]; then
    echo "FAIL: evaledModuleWithForce.fileWithStorePathOverride store path is incorrect: $file9"
    exit 1
  fi

  file10="${evaledModuleWithDefault.config.fileWithContent.path}"
  if [ ! -f "$file10" ]; then
    echo "FAIL: evaledModuleWithDefault.fileWithContent does not exist"
    exit 1
  fi
  content10=$(cat "$file10")
  if [ "$content10" != "test content4" ]; then
    echo "FAIL: evaledModuleWithDefault.fileWithContent has incorrect content: $content10"
    exit 1
  fi
  # Check fileWithPathOverride
  file11="${evaledModuleWithDefault.config.fileWithPathOverride.path}"
  if [ "$file11" != "/etc/hosts4" ]; then
    echo "FAIL: evaledModuleWithDefault.fileWithPathOverride path is incorrect: $file11"
    exit 1
  fi
  # Check fileWithStorePathOverride
  file12="${evaledModuleWithDefault.config.fileWithStorePathOverride.path}"
  expectedStorePath="${pkgs.writeText "custom-file4" "custom content4"}"
  if [ "$file12" != "$expectedStorePath" ]; then
    echo "FAIL: evaledModuleWithDefault.fileWithStorePathOverride store path is incorrect: $file12"
    exit 1
  fi

  file13="${evaledModuleWithOptionDefault.config.fileWithContent.path}"
  if [ ! -f "$file13" ]; then
    echo "FAIL: evaledModuleWithOptionDefault.fileWithContent does not exist"
    exit 1
  fi
  content13=$(cat "$file13")
  if [ "$content13" != "test content5" ]; then
    echo "FAIL: evaledModuleWithOptionDefault.fileWithContent has incorrect content: $content13"
    exit 1
  fi
  echo "SUCCESS: types.file test passed"
  touch $out
''
