include $(B_BASE)/common.mk
include $(B_BASE)/rpmbuild.mk

IPROG=install -m 755
IDATA=install -m 644

LIBEXECDIR?=/opt/xensource/libexec

$(TARGETS):
.PHONY: build
build:
	omake build

.PHONY: clean
clean:
	omake clean

.PHONY: install
install: build
	mkdir -p $(DESTDIR)$(LIBEXECDIR)/xcp-rrdd-plugins/
	$(IPROG) src/rrdp_gpumon.opt $(DESTDIR)$(LIBEXECDIR)/xcp-rrdd-plugins/xcp-rrdd-gpumon
	mkdir -p $(DESTDIR)/etc/rc.d/init.d
	$(IPROG) scripts/init.d-rrdd-gpumon $(DESTDIR)/etc/rc.d/init.d
