.PHONY: build static test

V ?= v
BIN_DIR := ./bin
BUILD_BIN := $(BIN_DIR)/bash2v
STATIC_BIN := $(BIN_DIR)/bash2v_static

build:
	mkdir -p $(BIN_DIR)
	$(V) -prod -o $(BUILD_BIN) ./cmd/bash2v

static:
	mkdir -p $(BIN_DIR)
	$(V) -prod -o $(STATIC_BIN) ./cmd/bash2v

test:
	$(V) test ./bash2v
	$(V) test ./tests
