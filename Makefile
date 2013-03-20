default: all
.PHONY: default all install doc test test-env ensure-dnanexus-home regenerate-wrappers clean gh-pages

all: src/setup.data src/DXAPI.ml src/DNAnexus.mli
	cd src && ocaml setup.ml -build

install: all
	ocamlfind remove DNAnexus || true
	cd src && ocaml setup.ml -install

doc: all src/setup.ml
	cd src && ocamlbuild -use-ocamlfind DNAnexus.docdir/index.html
	cp src/ocamldoc_style.css src/_build/DNAnexus.docdir/style.css

test:
	cd src && ocaml setup.ml -build unit_tests.native
	bash -c 'eval "`dx env --bash`" && src/unit_tests.native'

test-quick:
	cd src && ocaml setup.ml -build unit_tests.native
	bash -c 'eval "`dx env --bash`" && DX_SKIP_SLOW_TESTS=1 src/unit_tests.native'

# don't rely on ~/.dnanexus_config; require DX_* environment variables
test-env:
	cd src && ocaml setup.ml -build unit_tests.native
	src/unit_tests.native

src/setup.data: src/setup.ml
	cd src && ocaml setup.ml -configure

src/setup.ml: src/_oasis
	cd src && oasis setup

ensure-dnanexus-home:
	@bash -c '[[ "${DNANEXUS_HOME}" != "" ]] || (echo "Please initialize your environment with: source /path/to/dx-toolkit/environment" >&2; exit 1)'

src/DXAPI.ml:
	$(MAKE) ensure-dnanexus-home
	cat ${DNANEXUS_HOME}/build/wrapper_table.json | util/generateOCamlAPIWrappers_ml.py > src/DXAPI.ml

src/DNAnexus.mli: src/DNAnexus.TEMPLATE.mli
	$(MAKE) ensure-dnanexus-home
	cat ${DNANEXUS_HOME}/build/wrapper_table.json | util/generateOCamlAPIWrappers_mli.py > /tmp/DXAPI.mli
	sed -e "/<<<DXAPI.mli>>>/r /tmp/DXAPI.mli" -e "/<<<DXAPI.mli>>>/d" src/DNAnexus.TEMPLATE.mli > src/DNAnexus.mli

regenerate-wrappers:
	rm -f src/DXAPI.ml src/DNAnexus.mli
	$(MAKE) src/DXAPI.ml src/DNAnexus.mli

clean:
	cd src && (ocaml setup.ml -clean || ocamlbuild -clean) && rm -f *.ba?
	rm -f src/setup.data

gh-pages: clean
	rm -rf /tmp/DNAnexus.docdir
	$(MAKE) doc
	cp -r src/_build/DNAnexus.docdir /tmp
	git checkout gh-pages
	git pull origin gh-pages
	cp /tmp/DNAnexus.docdir/* .
	git commit -am 'update ocamldoc documentation [via make gh-pages]'
	git push origin gh-pages
	git checkout master
