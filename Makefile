DESTDIR ?= 
LIBEXECDIR ?= /opt/xensource/libexec

TESTS_FLAG=--enable-tests

J=4

LIBEXECDIR?=/opt/xensource/libexec

all: build

setup.data:
	ocaml setup.ml -configure $(TESTS_FLAG)

build: setup.data
	ocaml setup.ml -build -j $(J)

test: build
	ocaml setup.ml -test

clean:
	ocamlbuild -clean
	rm -f setup.data setup.log

.PHONY: install
install: build
	mkdir -p $(DESTDIR)$(LIBEXECDIR)/xcp-rrdd-plugins/
	install -m 755 _build/gpumon/gpumon.native $(DESTDIR)$(LIBEXECDIR)/xcp-rrdd-plugins/xcp-rrdd-gpumon
