# See LICENSE for licensing information.

REBAR ?= $(shell command -v rebar >/dev/null 2>&1 && echo "rebar" || echo "$(CURDIR)/rebar")

ELVIS ?= $(shell command -v elvis >/dev/null 2>&1 && echo "elvis" || echo "$(CURDIR)/elvis")

DEPS_PLT := $(CURDIR)/.deps_plt

ERLANG_DIALYZER_APPS := erts \
					    kernel \
						stdlib \
						inets

DIALYZER := dialyzer

# Travis CI is slow at building dialyzer PLT
ifeq ($(TRAVIS), true)
	OTP_VSN := $(shell erl -noshell -eval 'io:format("~p", [erlang:system_info(otp_release)]), erlang:halt(0).' | perl -lne 'print for /^(?:"R)?(\d+).*/g')
	NO_DIALYZER := $(shell expr $(OTP_VSN) \<= 16 )

	ifeq ($(NO_DIALYZER), 1)
		DIALYZER := : not running dialyzer on TRAVIS with R16 and below
	endif
endif

SRCS := $(wildcard src/* include/* rebar.config)

SRC_BEAMS := $(patsubst src/%.erl, ebin/%.beam, $(wildcard src/*.erl))

.PHONY: all
all: deps ebin/jesse.app bin/jesse

# Clean

.PHONY: clean
clean:
	$(REBAR) clean
	$(RM) -r .rebar
	$(RM) -r bin
	$(RM) doc/*.html
	$(RM) doc/edoc-info
	$(RM) doc/erlang.png
	$(RM) doc/stylesheet.css
	$(RM) -r ebin
	$(RM) -r logs

.PHONY: distclean
distclean:
	$(RM) $(DEPS_PLT)
	$(RM) -r deps
	$(MAKE) clean

# Deps

.PHONY: get-deps
get-deps:
	$(REBAR) get-deps

.PHONY: update-deps
update-deps:
	$(REBAR) update-deps

.PHONY: delete-deps
delete-deps:
	$(REBAR) delete-deps

.PHONY: deps
deps: get-deps

# Docs

.PHONY: docs
docs:
	$(REBAR) doc skip_deps=true

# Compile

ebin/jesse.app: compile

bin/jesse: ebin/jesse.app $(SRC_BEAMS)
	$(REBAR) escriptize
	bin/jesse --help

.PHONY: compile
compile: $(SRCS)
	$(REBAR) compile

# Tests.

.rebar/DEV_MODE:
	mkdir -p .rebar
	touch .rebar/DEV_MODE

.PHONY: submodules
submodules:
	git submodule update --init --recursive

.PHONY: test
test: .rebar/DEV_MODE deps submodules eunit ct dialyzer

.PHONY: eunit
eunit:
	$(REBAR) eunit skip_deps=true

.PHONY: ct
ct:
	$(REBAR) ct skip_deps=true suites="jesse_tests_draft3,jesse_tests_draft4"

$(DEPS_PLT):
	$(DIALYZER) --build_plt --apps $(ERLANG_DIALYZER_APPS) -r deps --output_plt $(DEPS_PLT)

.PHONY: dialyzer
dialyzer: $(DEPS_PLT) ebin/jesse.app
	$(DIALYZER) --plt $(DEPS_PLT) -Wno_return ebin

.PHONY: elvis
elvis:
	$(ELVIS) rock
