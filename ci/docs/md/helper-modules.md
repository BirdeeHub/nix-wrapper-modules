# wlib.modules

In this subsection are what we will call "helper modules".

They are just regular modules. The distinction is that they do not set `config.package`

Instead, their purpose is to create convenience options for you to use to define your own wrappers!

The example you will become most familiar with are the helper modules imported by `wlib.modules.default`

`wlib.modules.default` gets its options by importing 2 other modules, `wlib.modules.symlinkScript` and `wlib.modules.makeWrapper`.

But you could choose to have modules that have different abilities!

For example, someone may want to make a set of convenience options for wrapping your program with `bubblewrap` or some other sandboxing tool instead!

They could make a module for that, and submit it here for everyone to enjoy!
