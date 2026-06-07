# syntax=docker/dockerfile:1.4

ARG	LOCAL_CLOUDCLI_PATH=./cloudcli
ARG	LOCAL_PLUGINS_PATH=./plugins

ARG	NODE_VERSION="24"
ARG	APP_DIR="/app" PLUGINS_DIR="/opt/_cloudcli_plugins"
ARG	VITE_IS_PLATFORM=true

FROM	node:${NODE_VERSION}-slim AS base
RUN	--mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked <<EOF
	apt-get update
	apt-get --no-install-recommends install -y ca-certificates git python3
EOF
ARG	APP_DIR PLUGINS_DIR
ARG	VITE_IS_PLATFORM


FROM	base AS build
RUN	--mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked <<EOF
	apt-get --no-install-recommends install -y g++
EOF


FROM	build AS app-builder
ARG	TMP_DIR=/tmp/app
ARG	LOCAL_CLOUDCLI_PATH
ADD	${LOCAL_CLOUDCLI_PATH} ${TMP_DIR}
WORKDIR	${TMP_DIR}
RUN	--mount=type=cache,target=/root <<EOF
	npm ci
	npm run build
	PACKFILE=$(npm pack --silent)
	echo "${PACKFILE}"
	npm install --prefix ${APP_DIR} "${PACKFILE}"
	rm -rf ${TMP_DIR}
EOF


FROM	build AS plugin-builder
RUN	mkdir -p ${PLUGINS_DIR}
WORKDIR	${PLUGINS_DIR}
ARG	LOCAL_PLUGINS_PATH
ADD	${LOCAL_PLUGINS_PATH} ${PLUGINS_DIR}/
RUN	--mount=type=cache,target=/root <<EOF
	for plugin_dir in ${PLUGINS_DIR}/*; do
		echo "Building plugin: ${plugin_dir}";
		cd ${plugin_dir}
		npm ci
		npm run build
		npm prune --production
	done
EOF


FROM	base
COPY	--from=app-builder --link ${APP_DIR} ${APP_DIR}
COPY	--from=plugin-builder --link ${PLUGINS_DIR} ${PLUGINS_DIR}

RUN	--mount=type=cache,target=/root <<EOF
	npm install -g @anthropic-ai/claude-code task-master-ai
	npm cache clean --force
EOF

EXPOSE	3001

ENV	PLUGINS_DIR=${PLUGINS_DIR}
ENV	HOST_UID=1000 HOST_GID=1000
COPY	--link --chmod=+x ./entrypoint.sh /entrypoint.sh
ENTRYPOINT	["/entrypoint.sh"]

CMD	su - node -c VITE_IS_PLATFORM=${VITE_IS_PLATFORM} npx cloudcli
