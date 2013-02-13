default: all
.PHONY: default all install check-env doc test git-submodule-incantations tidy clean

export OCAMLPATH := ${DNANEXUS_HOME}/lib/ocaml:${OCAMLPATH}
export OCAMLFIND_DESTDIR := ${DNANEXUS_HOME}/lib/ocaml
export PATH := $(CURDIR)/twt:$(PATH)

all: check-env twt/ocaml+twt src/setup.data .JSON.loc .curl.loc
	cd src && ocaml setup.ml -build

install: check-env all
	ocamlfind remove DNAnexus || true
	cd src && ocaml setup.ml -install

doc: twt/ocaml+twt src/setup.ml .JSON.loc .curl.loc
	cd src && ocamlbuild -use-ocamlfind DNAnexus.docdir/index.html
	cp src/ocamldoc_style.css src/_build/DNAnexus.docdir/style.css

test:
	cd src && ocaml setup.ml -build unit_tests.native
	src/unit_tests.native

# Run unit tests using environment saved by dx following `dx login`
test-dx:
	cd src && ocaml setup.ml -build unit_tests.native
	bash -c "source ~/.dnanexus_config/environment && src/unit_tests.native"

src/setup.data: src/setup.ml .JSON.loc .curl.loc
	mkdir -p ${DNANEXUS_HOME}/lib/ocaml
	cd src && ocaml setup.ml -configure --destdir ${DNANEXUS_HOME}/lib/ocaml

src/setup.ml: src/_oasis
	cd src && oasis setup

twt/ocaml+twt: twt/ocaml+twt.ml
	cd twt && make

twt/ocaml+twt.ml: .gitmodules
	$(MAKE) git-submodule-incantations

# build & install yajl-ocaml libraries if necessary
.JSON.loc: .gitmodules
	$(MAKE) check-env
	test -d yajl-ocaml/extra || $(MAKE) git-submodule-incantations
	ocamlfind remove yajl || true
	ocamlfind remove yajl-extra || true
	mkdir -p ${DNANEXUS_HOME}/lib/ocaml
	cd yajl-ocaml && make install && make install-extra
	ocamlfind query yajl-extra > .JSON.loc	

# build & install ocurl if necessary
.curl.loc: .gitmodules
	$(MAKE) check-env
	test -f ocurl/configure || $(MAKE) git-submodule-incantations
	ocamlfind remove curl || true
	mkdir -p ${DNANEXUS_HOME}/lib/ocaml
	cd ocurl && ./configure && make && make install
	ocamlfind query curl > .curl.loc

check-env:
ifndef DNANEXUS_HOME
	$(error The DNANEXUS_HOME environment variable is not defined; source dx-toolkit/environment and try again.)
endif

git-submodule-incantations:
	git submodule init && git submodule sync && git submodule update

tidy:
	cd src && (ocaml setup.ml -clean || ocamlbuild -clean) && rm -f *.ba?

clean: tidy
	cd twt && (make clean || true)
	cd yajl-ocaml && (make clean || true)
	cd ocurl && (make clean || true)
	rm -f .JSON.loc .curl.loc src/setup.data
