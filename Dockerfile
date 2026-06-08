# syntax=docker/dockerfile:1.4

ARG	LOCAL_CLOUDCLI_PATH=./cloudcli
ARG	LOCAL_PLUGINS_PATH=./plugins

ARG CLAUDE_CODE_VERSION="latest"
ARG	NODE_VERSION="24"
ARG	APP_DIR="/app" PLUGINS_DIR="/opt/_cloudcli_plugins"
ARG	APP_PATH=${APP_DIR}/node_modules/.bin/cloudcli
ARG	VITE_IS_PLATFORM=true

FROM	node:${NODE_VERSION}-trixie-slim AS base
RUN	--mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked <<EOF
	apt-get update
	apt-get --no-install-recommends install -y ca-certificates git python3
EOF
# ARG	NODE_VERSION
# RUN	--mount=type=cache,target=/var/cache/apt,sharing=locked \
# 	--mount=type=cache,target=/var/lib/apt,sharing=locked <<EOF
# 	curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
# 	apt-get --no-install-recommends install -y nodejs
# EOF
ARG	APP_DIR PLUGINS_DIR APP_PATH
ARG	VITE_IS_PLATFORM


FROM	base AS build
RUN	--mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked <<EOF
	apt-get update
	apt-get --no-install-recommends install -y make g++
EOF


FROM	build AS app-builder
ARG	TMP_DIR=/tmp/app
ARG	LOCAL_CLOUDCLI_PATH
ADD	${LOCAL_CLOUDCLI_PATH} ${TMP_DIR}
WORKDIR	${TMP_DIR}
RUN	<<EOF
	npm approve-scripts --all 2> /dev/null || true
	npm ci 2> /dev/null || npm install
	npm run build
	PACKFILE=$(npm pack --silent)
	echo "${PACKFILE}"
	npm install --prefix ${APP_DIR} "${PACKFILE}"
	rm -rf ${TMP_DIR}
EOF
RUN test -x ${APP_PATH}
COPY --link <<EOF ${APP_DIR}/node_modules/@cloudcli-ai/cloudcli/.env
	VITE_IS_PLATFORM=${VITE_IS_PLATFORM}
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
		npm approve-scripts --all 2> /dev/null || true
		npm ci 2> /dev/null || npm install
		npm run build
		npm prune --production
	done
EOF


FROM	build AS node_modules
ARG	CLAUDE_CODE_VERSION
RUN	<<EOF
	npm approve-scripts --all 2> /dev/null || true
	npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} task-master-ai
	npm cache clean --force
EOF


FROM	base
RUN	<<EOF
	curl -LsSf https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL=/usr/local/bin sh
EOF
RUN	--mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked <<EOF
	apt-get update
	apt-get --no-install-recommends install -y jq less ripgrep unzip vim
EOF
RUN	<<EOF
	echo "source /etc/skel/.bashrc" | su - node -c "tee ~/.bashrc"
EOF

RUN	<<EOF
	cd /usr/local/bin
	ln -sf ../lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe claude
	ln -sf ../lib/node_modules/task-master-ai/dist/task-master.js task-master
	ln -sf ../lib/node_modules/task-master-ai/dist/mcp-server.js task-master-ai
	ln -sf ../lib/node_modules/task-master-ai/dist/mcp-server.js task-master-mcp
EOF

COPY	--from=app-builder --link ${APP_DIR} ${APP_DIR}
COPY	--from=plugin-builder --link ${PLUGINS_DIR} ${PLUGINS_DIR}
COPY	--from=node_modules --link /usr/local/lib/node_modules /usr/local/lib/node_modules

EXPOSE	3001

USER	node

ENV	PLUGINS_DIR=${PLUGINS_DIR}
COPY	--link ./entrypoint.sh /
ENTRYPOINT	["/entrypoint.sh"]

CMD	/app/node_modules/.bin/cloudcli
