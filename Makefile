# vim: set noet ts=8:
#
# This Makefile is not called from Opam but only used for
# convenience during development
#

LIBEXECDIR 	?= /opt/xensource/libexec
PLUGINS     	= $(DESTDIR)$(LIBEXECDIR)/xcp-rrdd-plugins
BUILD       	= _build/default
DUNE 		= dune
PROFILE 	= release

.PHONY: install all clean test mock

all:
	$(DUNE) build --profile=$(PROFILE)

install: all
	install -D -m 755 $(BUILD)/gpumon/gpumon.exe $(PLUGINS)/xcp-rrdd-gpumon

clean:
	$(DUNE) clean

test:
	$(DUNE) runtest


format:
	$(DUNE) build @fmt --auto-promote
	git ls-files '**/*.[ch]' | xargs -n1 indent -nut -kr

mock:
	cp mocks/mock.ml lib/nvml.ml
	cp mocks/mock.c  stubs/nvml_stubs.c

unmock:
	git checkout -- lib/nvml.ml stubs/nvml_stubs.c
