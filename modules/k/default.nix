# Anything starting with the letter this dirname represents will be
# expected to be a directory with a ./module.nix file inside.
# Anything else will be ignored by default.

# if this subgrouping wishes to export things other than
# { wrapperModules, checks }, it can merge them in here
# // { modules = { ... some modules ... }; } will be included in lib.modules

# Everything else will appear under lib.misc.<that_name>.urthing
# so in order to avoid conflicts,
# anything else should be included under // { dirname = { ... your stuff ... }; }
{
  callDirs,
  dirname,
  wlib,
  lib,
  dirpath,
  ...
}@args:
callDirs args
