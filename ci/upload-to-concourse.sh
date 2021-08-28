#!/usr/bin/env bash

set -e

if [ -z "$CONCOURSE_TARGET" ]; then
    echo "Missing CONCOURSE_TARGET env var."
    exit 1
fi

if [ -z "$CONCOURSE_URL" ]; then
    echo "Missing CONCOURSE_URL env var."
    exit 1
fi

if [ -z "$CONCOURSE_USER" ]; then
    echo "Missing CONCOURSE_USER env var."
    exit 1
fi

if [ -z "$CONCOURSE_PASSWORD" ]; then
    echo "Missing CONCOURSE_PASSWORD env var."
    exit 1
fi

if [ ! -f "vars.ym