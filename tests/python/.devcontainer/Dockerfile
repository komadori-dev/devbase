FROM ghcr.io/komadori-dev/devbase:latest

ENV PYTHONPATH=/workspace/python-example \
    PIP_ROOT_USER_ACTION=ignore \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1

RUN apk add --no-cache python3 py3-pip

WORKDIR /workspace/python-example