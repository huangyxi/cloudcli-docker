#!/bin/sh
set -e

HOME=/home/node
PLUGIN_PREFIX="_baked_"
PLUGINS_DEST="${HOME}/.claude-code-ui/plugins"
PLUGINS_DIR=${PLUGINS_DIR:-/plugins}
HOST_UID=${HOST_UID:-1000}
HOST_GID=${HOST_GID:-1000}

if [ "$(id -u node)" -eq ${HOST_UID} ]; then
	usermod -u ${HOST_UID} node
fi
if [ "$(id -g node)" -eq ${HOST_GID} ]; then
	groupmod -g ${HOST_GID} node
fi

if [ "$(stat -c '%u' ${HOME})" -ne "$(id -u node)" ] || [ "$(stat -c '%g' ${HOME})" -ne "$(id -g node)" ]; then
	chown -R node:node ${HOME}
fi

run_as_node() {
	su - node -c "$*"
}

run_as_node mkdir -p "$PLUGINS_DEST"

for existing_plugin in "$PLUGINS_DEST/$PLUGIN_PREFIX"*; do
	run_as_node rm -rf "$existing_plugin"
done

for plugin_path in ${PLUGINS_DIR}/*; do
	if [ -d "${plugin_path}" ]; then
		plugin_name=$(basename "${plugin_path}")
		run_as_node cp -R "${plugin_path}" "${PLUGINS_DEST}/${PLUGIN_PREFIX}${plugin_name}"
	fi
done

if [ "${1#-}" != "${1}" ] || [ -z "$(command -v "${1}")" ] || { [ -f "${1}" ] && ! [ -x "${1}" ]; }; then
	set -- node "$@"
fi

exec "$@"
