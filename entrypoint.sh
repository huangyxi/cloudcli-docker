#!/bin/sh
set -e

PLUGIN_PREFIX="_baked_"
PLUGINS_DEST="${HOME}/.claude-code-ui/plugins"
PLUGINS_DIR=${PLUGINS_DIR:-/plugins}

run_as_user() {
	su - ${USER:-root} -c "$*"
}

run_as_user mkdir -p "$PLUGINS_DEST"

for existing_plugin in "$PLUGINS_DEST/$PLUGIN_PREFIX"*; do
	run_as_user rm -rf "$existing_plugin"
done

for plugin_path in ${PLUGINS_DIR}/*; do
	if [ -d "${plugin_path}" ]; then
		plugin_name=$(basename "${plugin_path}")
		run_as_user cp -R "${plugin_path}" "${PLUGINS_DEST}/${PLUGIN_PREFIX}${plugin_name}"
	fi
done

if [ "${1#-}" != "${1}" ] || [ -z "$(command -v "${1}")" ] || { [ -f "${1}" ] && ! [ -x "${1}" ]; }; then
	set -- node "$@"
fi

exec "$@"
