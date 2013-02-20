# DNAnexus API bindings for OCaml

These bindings are *not* officially supported by DNAnexus!

## Dependencies

dx-ocaml depends on a few other OCaml libraries. The best way to install them
is to use the [OPAM](http://opam.ocamlpro.com/doc/Quick_Install.html) package
manager. Install it, then

```eval $(opam config -env) && opam install batteries ocaml+twt ocurl ssl yajl-extra```

Compiling [ocurl](http://ocurl.forge.ocamlcore.org/) may require you to
install a fairly recent version of [libcurl](http://curl.haxx.se/libcurl/).
The Ubuntu 12.10 libcurl-dev package works.

Lastly, you should have a working installation of
[dx-toolkit](http://wiki.dnanexus.com/Downloads#DNAnexus-Platform-SDK).

## Installation

Just `make install` in this directory. The `DNAnexus` findlib package will be
installed to the default destination (most likely within your OPAM directory).

## API documentation

[ocamldoc:DNAnexus](http://mlin.github.com/dx-ocaml/DNAnexus.html)

## Writing DNAnexus platform apps

A suggested way to get started:

1. Use `dx-app-wizard` to initialize a basic _C++_ applet. See the [Writing
DNAnexus Apps in C++](http://wiki.dnanexus.com/Developer-Tutorials/Cpp/Cpp)
tutorial.
1. Start writing some OCaml code in the `src/` subdirectory of the new applet
directory. Use the `DNAnexus.job_main` function as the entry point to help
deal with job input and output. (You can delete the auto-generated
`src/your_app_name.cpp` if you wish.)
1. Rewrite the `src/Makefile` so that it builds your OCaml program instead of
the template C++ program. Be sure to make the `DNAnexus` findlib package
available for compiling and linking.
1. Make the `src/Makefile` also move or copy the compiled executable to
`../resources/your_app_name` - the same target as the original C++ Makefile.
(The `runSpec` entry in `dxapp.json` causes this executable to run when the
job starts.)
1. Initialize your DNAnexus command-line session with `source
/path/to/dx-toolkit/environment && dx login`, then run `dx-build-applet` to
build the applet.

## Examples

TODO: link to some example applets

## Version history

## Wish list

- Load configuration from ~/.dnanexus_config
- Safer (route-specific) retry logic
- Streaming JSON processing for GTables
