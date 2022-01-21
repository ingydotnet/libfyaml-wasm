SHELL := bash

ifeq (,$(shell command -v node))
    $(error 'node' required)
endif
ifeq (,$(shell command -v npm))
    $(error 'npm' required)
endif

BASE ?= $(shell pwd)

LIBFYAML=$(BASE)/libfyaml
EMSDK=$(BASE)/emskd
NODE_MODULES=$(BASE)/node_modules
BUILD_OPTS := \
    -g3 \
    -I $(LIBFYAML)/src/valgrind \
    -I $(LIBFYAML)/include \
    -L $(LIBFYAML)/src/.libs \
    -l fyaml \

BUILD_OPTS_MODULE := \
    -s MODULARIZE \
    -s EXPORTED_FUNCTIONS=_main \
    -s EXPORTED_RUNTIME_METHODS=ccall \

NODE_BIN := $(EMSDK)/node/14.18.2_64bit/bin
PATHS := $(EMSDK)
PATHS := $(PATHS):$(EMSDK)/upstream/emscripten
PATHS := $(PATHS):$(NODE_BIN)
PATHS := $(PATHS):$(NODE_MODULES)/bin
export PATH := $(PATHS):$(PATH)
export EMSDK
export EM_CONFIG := $(EMSDK)/.emscripten
export EMSDK_NODE := $(NODE_BIN)/node

FYTOOL := $(LIBFYAML)/fy-tool
FYTOOL_SRC := $(LIBFYAML)/src/tool/fy-tool.c
LIBFYAML_H := $(LIBFYAML)/include/libfyaml.h
CONFIGURE := $(LIBFYAML)/configure
MAKEFILE_ := $(LIBFYAML)/Makefile
BOOTSTRAP := $(LIBFYAML)/bootstrap.sh
RUNNER := $(BASE)/runner
export NODE_PATH := $(LIBFYAML)

define runner
require 'ingy-prelude'

require('fy-tool')().then (fy)->
  say fy.ccall('main', null, [['string']], ['--help'])
endef
export runner

#------------------------------------------------------------------------------
default:

test: test-events

test-events: $(FYTOOL)
	node $< --testsuite <<<'foo: bar'

test-runner: $(NODE_MODULES) $(RUNNER) $(FYTOOL).js
	node $(RUNNER) <<<'foo: bar'

test-html: $(FYTOOL).html
ifeq (,$(shell command -v python3))
	$(error 'python3' required)
endif
ifeq (,$(shell command -v firefox))
	$(error 'firefox' required)
endif
	(cd $(BASE); python3 -m http.server 8000 & echo $$! > /tmp/pid)
	firefox --new-window localhost:8000/libfyaml/fy-tool.html
	kill -9 $$(< /tmp/pid)
	rm /tmp/pid

clean:
	rm -fr $(LIBFYAML) $(RUNNER)

realclean: clean
	rm -fr $(EMSDK) $(NODE_MODULES)

#------------------------------------------------------------------------------
$(FYTOOL): $(FYTOOL_SRC) $(LIBFYAML_H)
	cd $(LIBFYAML) && \
	emcc $< \
	    $(BUILD_OPTS) \
	    -o fy-tool.js
	mv $@.js $@

$(FYTOOL).js: $(FYTOOL_SRC) $(LIBFYAML_H)
	cd $(LIBFYAML) && \
	emcc $< \
	    $(BUILD_OPTS) \
	    $(BUILD_OPTS_MODULE) \
	    -o $@

$(FYTOOL).html: $(FYTOOL_SRC) $(LIBFYAML_H)
	cd $(LIBFYAML) && \
	emcc $< \
	    $(BUILD_OPTS) \
	    -o fy-tool.html

$(RUNNER): Makefile
	coffee -cps <<<"$$runner" > $@

$(FYTOOL_SRC): $(LIBFYAML)

$(LIBFYAML_H): $(MAKEFILE_) $(EMSDK)
	cd $(LIBFYAML) && emmake $(MAKE)

$(MAKEFILE_): $(CONFIGURE) $(EMSDK)
	cd $(LIBFYAML) && emconfigure $<

$(CONFIGURE):
	cd $(LIBFYAML) && ./bootstrap.sh

$(LIBFYAML):
	git clone git@github.com:pantoniou/libfyaml $@

$(EMSDK):
	git clone https://github.com/emscripten-core/emsdk $@
	( \
	    cd $@; \
	    ./emsdk install latest; \
	    ./emsdk activate latest; \
	)

$(NODE_MODULES):
	mkdir -p $@
	cd $$(dirname $(NODE_MODULES)) && \
	npm install coffeescript ingy-prelude
