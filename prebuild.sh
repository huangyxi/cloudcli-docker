#!/usr/bin/env bash

CLOUDCLI_DIR=cloudcli
PLUGINS_DIR=plugins
CLOUDCLI_REF=${CLOUDCLI_REF:-main}

git_clone() {
	git clone --depth 1 "$@"
}

git_clone --branch ${CLOUDCLI_REF} https://github.com/siteboon/claudecodeui.git "${CLOUDCLI_DIR}"

mkdir -p "${PLUGINS_DIR}"
cd "${PLUGINS_DIR}"

# Build the terminal plugin since node-tty need to be built for the target platform especially for arm64
git_clone https://github.com/cloudcli-ai/cloudcli-plugin-terminal
