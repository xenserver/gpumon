# vim: set noet ts=8:
#
# This Makefile is not called from Opam but only used for
# convenience during development
#

LIBEXECDIR 	?= /opt/xensource/libexec
PLUGINS     	= $(LIBEXECDIR)/xcp-rrdd-plugins
BUILD       	= _build/default
DUNE 		= dune

.PHONY: install all clean test

all:
	$(DUNE) build

install: all
	install -D -m 755 $(BUILD)/gpumon/gpumon.exe $(PLUGINS)/xcp-rrdd-gpumon

clean:
	$(DUNE) clean

test:
	$(DUNE) runtest



