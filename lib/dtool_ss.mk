
DOTOOL_ss := $(shell realpath --relative-to="$(DTOOL_HOME)" "$(CURDIR)")

# Isolated mode values:
DOTOOL_ss_network=testnet
DOTOOL_ss_instance=genesis
DOTOOL_m=m1
# Isolated/Managed modes
DOTOOL_CACHE__DEBUG=$(DTOOL_HOME)/.dtool/dotool/cache/debug/${DOTOOL_ss}
DOTOOL_CACHE__RELEASE=$(DTOOL_HOME)/.dtool/dotool/cache/release/${DOTOOL_ss}
DOTOOL_FILE=dotool.env


all: _output

_output: dotool
	bin/build_install

dotool: ${DOTOOL_FILE}
	@echo ${DOTOOL_FILE}

${DOTOOL_FILE}:
	dotool make_ss ${DOTOOL_ss} ${DOTOOL_ss_network} ${DOTOOL_ss_instance} ${DOTOOL_m} ${DOTOOL_FILE}

clean:
	$(RM) -r _output

clean_cache: clean
	$(RM) -r ${DOTOOL_CACHE__DEBUG}
	$(RM) -r ${DOTOOL_CACHE__RELEASE}

clean_deep: clean
	$(RM) ${DOTOOL_FILE}

print-dirs:
	@echo "Closest .dtool directory (DTOOL_HOME): $(DTOOL_HOME)"
	@echo "libdir (DTOOL_LIBDIR): $(DTOOL_LIBDIR)"
	@echo "Current directory (CURDIR): $(CURDIR)"
	@echo "SS $(DOTOOL_ss)"

.PHONY: all install dotool clean clean_cache clean_deep print-dirs

# -/---------------- dotool targets
