`luaInit` is a flexible configuration option for providing Lua code that will be executed when the Lua environment for `xplr` is initialized.

It can be either a simple string of Lua code or a structured DAG (directed acyclic graph) of Lua code snippets with dependencies between them.

The dag type has an extra `opts` field that can be used to pass in options to the lua code.

It is like the `config.luaInfo` option, but per entry.

You can then receive it in `.data` with `local opts, name = ...`

`{ data, after ? [], before ? [], opts ? {}, enable ? true, plugin ? null, type ? config.defaultConfigLang }`

**Example usage:**

```nix
luaEnv = lp: [ lp.inspect ];
luaInit.WillRunEventually = ''
  print([[
    you can also just put a string if you currently don't need opts,
    don't have ordering requirements, etc...

    config.luaInit.WillRunEventually.data will be this string.
    You can still add other stuff later.
  ]])
'';
luaInit.TESTFILE_1 = {
  opts = { testval = 1; };
  data = /* lua */''
    local opts, name = ...
    print(name, require("inspect")(opts), "${placeholder "out"}")
    return opts.hooks -- xplr configurations can return hooks
  '';
};
luaInit.TESTFILE_2 = {
  opts = { testval = 2; };
  after = [ "TESTFILE_1" ];
  type = "fnl";
  data = /* fennel */ ''
    (local (opts name) ...)
    (print name ((require "inspect") opts) "${placeholder "out"}")
    (. opts hooks) ;; xplr configurations can return hooks
  '';
};
```

Here, `TESTFILE_1` runs before `TESTFILE_2`, with their respective options passed in.

`WillRunEventually` will run at some point, but when is not specified. It could even run between `TESTFILE_1` and `TESTFILE_2`

The resulting generated file is given the name `GENERATED_WRAPPER_LUA` in the `DAG` for the `config.flags` and `config.addFlag` options, and it is added using `-c` or `--config` flag.

`xplr` accepts an arbitrary number of config files passed via the `-C` or `--extra-config` flag to extend this configuration, so you may pass extra yourself if you wish.
