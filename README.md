# DNAnexus API bindings for OCaml

These bindings are *not* officially supported by DNAnexus.

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

First, initialize your command-line session with `source
/path/to/dx-toolkit/environment` and `dx login`. Then, just `make install` in
this directory.

Libraries will be installed to: `$DNANEXUS_HOME/lib/ocaml` where
`$DNANEXUS_HOME` is the directory of your dx-toolkit installation.

## Compiling OCaml programs using the bindings

To make the bindings visible to OCaml findlib, add `$DNANEXUS_HOME/lib/ocaml`
to the `OCAMLPATH` environment variable. (In the shell, just `export
OCAMLPATH=$DNANEXUS_HOME/lib/ocaml:$OCAMLPATH`.) You can then use the
`DNAnexus` findlib package to compile against the bindings (see below for
interface documentation).

## Writing DNAnexus platform apps

A suggested way to get started:

1. Use `dx-app-wizard` to initialize a basic _C++_ applet. See the [Writing
DNAnexus Apps in C++](http://wiki.dnanexus.com/Developer-Tutorials/Cpp/Cpp)
tutorial.
1. Start writing some OCaml code in the `src/` subdirectory of the new applet
directory. Use the `DNAnexus.job_main` function as the entry point to help
deal with job input and output.
1. Rewrite the `src/Makefile` so that it builds your OCaml program instead of
the auto-generated C++ program.  It might be useful to put `export OCAMLPATH
:= ${DNANEXUS_HOME}/lib/ocaml:${OCAMLPATH}` at the top of the Makefile.
1. The Makefile should cause the compiled executable to be placed in
`../resources/your_app_name` -- the same target as the original C++ Makefile.
The `runSpec` entry in `dxapp.json` causes this executable to run when the
job starts.
1. Delete the auto-generated `src/your_app_name.cpp` if you wish.
1. Run `dx-build-app` as usual to build the applet.

## Examples

TODO: link to some example applets

## Documentation

TODO: place link to ocamldoc

## Version history

## Wish list

- Safer (route-specific) retry logic
- Streaming JSON processing for GTables
