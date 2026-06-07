#!/bin/sh
set -e

APP_USER=$(id -un)
APP_HOME=$(getent passwd "$APP_USER" | cut -d: -f6)

PLUGIN_PREFIX="_baked_"
PLUGINS_DEST="${APP_HOME}/.claude-code-ui/plugins"
PLUGINS_DIR=${PLUGINS_DIR:-/plugins}

mkdir -p "$PLUGINS_DEST"

for existing_plugin in "$PLUGINS_DEST/$PLUGIN_PREFIX"*; do
	if [ -e "$existing_plugin" ]; then
		rm -rf "$existing_plugin"
	fi
done

for plugin_path in "${PLUGINS_DIR}"/*; do
	if [ -d "${plugin_path}" ]; then
		plugin_name=$(basename "${plugin_path}")
		cp -R "${plugin_path}" "${PLUGINS_DEST}/${PLUGIN_PREFIX}${plugin_name}"
	fi
done

if [ "${1#-}" != "${1}" ] || [ -z "$(command -v "${1}")" ] || { [ -f "${1}" ] && ! [ -x "${1}" ]; }; then
	set -- node "$@"
fi

exec "$@"
