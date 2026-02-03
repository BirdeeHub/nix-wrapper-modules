{
  lib,
  collectOptions,
}:
{
  graph,
  options,
  transform ? x: if builtins.elem "_module" x.loc then [ ] else [ x ],
  ...
}:
let
  get-meta =
    descs: authors:
    let
      zipper = builtins.zipAttrsWith (
        file: xs: {
          inherit file;
          description = builtins.foldl' (
            acc: v:
            acc
            // {
              ${if v.desc.pre or "" != "" then "pre" else null} =
                (if acc.desc.pre or "" != "" then acc.desc.pre + "\n\n" else "") + v.desc.pre;
              ${if v.desc.post or "" != "" then "post" else null} =
                (if acc.desc.post or "" != "" then acc.desc.post + "\n\n" else "") + v.desc.post;
            }
          ) { } xs;
          maintainers = builtins.filter (v: v != null) (map (v: v.ppl or null) xs);
        }
      );
      descriptions = map (v: {
        ${v.file} = {
          desc = v;
        };
      }) descs;
      maintainers = map (v: {
        ${v.file} = {
          ppl = v;
        };
      }) authors;
    in
    zipper (descriptions ++ maintainers);

  # associate module files from graph with items in meta-info
  # all imports get grouped until the next one with an item in meta-info is found
  # merge the associated file paths into your meta-info for each item
  associate =
    let
      mergemeta =
        meta: file: new:
        meta
        // {
          ${file} = meta.${file} or { } // {
            associated = meta.${file}.associated or [ ] ++ [ new ];
          };
        };
      associate' =
        current:
        builtins.foldl' (
          acc: v:
          if acc.${v.file} or null != null then
            associate' v.file (mergemeta acc v.file v.file) v.imports
          else if current == null then
            associate' current (mergemeta acc v.file v.file) v.imports
          else
            associate' current (mergemeta acc current v.file) v.imports
        );
    in
    associate' null;

  # This will be used to sort the options from collectOptions
  modules-by-meta =
    lib.pipe (get-meta options.meta.description.value options.meta.maintainers.value)
      [
        (v: associate v graph)
        (lib.mapAttrsToList (file: v: if v ? file then v else v // { inherit file; }))
      ];

  partitioned =
    lib.partition (v: v.internal or false == true || v.visible or true == false)
      (collectOptions {
        inherit options transform;
      });
  invisible = lib.partition (v: v.internal or false == true) partitioned.right;

  anon_name = "<unknown-file>";
  groupByDecl =
    opts:
    builtins.zipAttrsWith (n: xs: xs) (
      builtins.concatMap (
        v:
        map (n: {
          ${n} = v;
          # NOTE: what to do with items without anything in declarations? That can happen if the type definition is messed up.
          # Right now we group them all under "<unknown-file>"
        }) (if v.declarations or [ ] == [ ] then [ anon_name ] else v.declarations)
      ) opts
    );

  internal = groupByDecl invisible.right;
  hidden = groupByDecl invisible.wrong;
  visible = groupByDecl partitioned.wrong;

in
lib.pipe modules-by-meta [
  (builtins.concatMap (
    v:
    lib.optional (internal ? "${v.file}" || hidden ? "${v.file}" || visible ? "${v.file}") (
      v
      // {
        ${if internal ? "${v.file}" then "internal" else null} =
          internal.${v.file} ++ lib.optional (v.file == anon_name) (internal.${anon_name} or [ ]);
        ${if hidden ? "${v.file}" then "hidden" else null} =
          hidden.${v.file} ++ lib.optional (v.file == anon_name) (hidden.${anon_name} or [ ]);
        ${if visible ? "${v.file}" then "visible" else null} =
          visible.${v.file} ++ lib.optional (v.file == anon_name) (visible.${anon_name} or [ ]);
      }
    )
  ))
  (
    v:
    lib.reverseList v
    ++
      lib.optional
        (
          builtins.all (v: v.file != anon_name) v && internal ? "${anon_name}"
          || hidden ? "${anon_name}"
          || visible ? "${anon_name}"
        )
        {
          file = anon_name;
          ${if internal ? "${anon_name}" then "internal" else null} = internal.${anon_name};
          ${if hidden ? "${anon_name}" then "hidden" else null} = hidden.${anon_name};
          ${if visible ? "${anon_name}" then "visible" else null} = visible.${anon_name};
        }
  )
]
