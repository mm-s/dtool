SHELL := /bin/bash

DTOOL_HOME := $(shell d=$$(pwd); while [ "$$d" != "/" ]; do \
    if [ -d "$$d/.dtool" ]; then echo $$d; exit; fi; \
    d=$$(dirname "$$d"); \
done; echo $$HOME)

DTOOL_LIBDIR := $(shell set -a; . "$(DTOOL_HOME)/.dtool/env"; set +a; echo "$${libdir}")

include $(DTOOL_LIBDIR)/lib/dtool_ss.mk




