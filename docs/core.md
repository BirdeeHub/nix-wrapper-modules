# Core (builtin) Options set

These are the core options that make everything else possible.

They include the `.apply`, `.eval`, and `.wrap` functions, and the `.wrapper` itself

They are always imported with every module evaluation.

They are very minimal by design.

The default `symlinkScript` value provides no options.

The default `wrapperFunction` is null.

`wlib.modules.default` provides great values for these options, and creates many more for you to use.

But you may want to wrap your package via different means, provide different options, or provide modules for others to use to help do those things!

Excited to see what ways to use these options everyone comes up with! Docker helpers? BubbleWrap? If it's a derivation, it should be possible!

---


