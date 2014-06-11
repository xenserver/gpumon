include $(B_BASE)/common.mk
include $(B_BASE)/rpmbuild.mk

IPROG=install -m 755
IDATA=install -m 644

J=4

LIBEXECDIR?=/opt/xensource/libexec

all: build

setup.data:
	ocaml setup.ml -configure

build: setup.data
	ocaml setup.ml -build -j $(J)

clean:
	ocamlbuild -clean
	rm -f setup.data setup.log

.PHONY: install
install: build
	mkdir -p $(DESTDIR)$(LIBEXECDIR)/xcp-rrdd-plugins/
	$(IPROG) _build/gpumon/gpumon.native $(DESTDIR)$(LIBEXECDIR)/xcp-rrdd-plugins/xcp-rrdd-gpumon
	mkdir -p $(DESTDIR)/etc/rc.d/init.d
	$(IPROG) scripts/init.d-rrdd-gpumon $(DESTDIR)/etc/rc.d/init.d/xcp-rrdd-gpumon
