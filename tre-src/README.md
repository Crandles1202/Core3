# tre-src — sources of `finalboss.tre`

Everything under this folder is packed into `MMOCoreORB/bin/tre/finalboss.tre` by `tools/tre build`
(`tools/swg tre build`). Paths mirror the archive: `string/en/fb_jedi.stf.txt` here becomes
`string/en/fb_jedi.stf` in the archive, which the client and server read as `@fb_jedi:<key>`.

- `*.stf.txt` under `string/<lang>/` are compiled into `.stf` string tables. One `key = text` per line,
  `#` starts a comment, `\n` inside the text is a line break. Keys: letters, digits, `_ . -`.
- Any other file is packed as-is (an `.iff` object template, a `.stf` you built elsewhere, …).
- Keep file names `fb_*` so they never shadow a stock file by accident. A path that exists in a stock
  tre **replaces** it everywhere (the server and the client both take the first archive that has it).

The built archive is not committed. The server reads it from its `TrePath` (`/tre/finalboss.tre`,
installed by `tools/swg tre install`, which `swg start` runs for you); the client needs the same file
in its folder plus a `searchTree_00_N=finalboss.tre` line at the top of its `swgemu_live.cfg`
(`tools/swg tre install --client '<client folder>'` does both once it knows the folder).

The server caches string tables in its object database: after a string change it must be started with
the `reloadstrings` argument. `swg start` does that automatically whenever the installed archive differs
from the one the previous start saw.
