EXE:=basic_ocaml_applet.native

all: build install

build:
	ocamlbuild -use-ocamlfind ${EXE}

install: build
	mkdir -p ../resources/usr/bin
	cp -f ${EXE} ../resources/usr/bin

clean:
	ocamlbuild -clean
	rm -f ../resources/usr/bin/${EXE}

.PHONY: all clean build install
