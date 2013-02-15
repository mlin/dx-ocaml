default: all
.PHONY: default all install doc test test-env clean

all: src/setup.data
	cd src && ocaml setup.ml -build

install: check-env all
	ocamlfind remove DNAnexus || true
	cd src && ocaml setup.ml -install

doc: src/setup.ml
	cd src && ocamlbuild -use-ocamlfind DNAnexus.docdir/index.html
	cp src/ocamldoc_style.css src/_build/DNAnexus.docdir/style.css

test:
	cd src && ocaml setup.ml -build unit_tests.native
	bash -c "source ~/.dnanexus_config/environment && src/unit_tests.native"

test-quick:
	cd src && ocaml setup.ml -build unit_tests.native
	bash -c "source ~/.dnanexus_config/environment && DX_SKIP_SLOW_TESTS=1 src/unit_tests.native"

# don't rely on ~/.dnanexus_config; require DX_* environment variables
test-env:
	cd src && ocaml setup.ml -build unit_tests.native
	src/unit_tests.native

src/setup.data: src/setup.ml
	cd src && ocaml setup.ml -configure

src/setup.ml: src/_oasis
	cd src && oasis setup

clean:
	cd src && (ocaml setup.ml -clean || ocamlbuild -clean) && rm -f *.ba?
	rm -f src/setup.data
