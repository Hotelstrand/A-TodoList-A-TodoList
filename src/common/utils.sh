#!/usr/bin/env bash

function pid_is_running() {
  declare pid="$1"
  ps -p "${pid}" >/dev/null 2>&1
}

# pid_guard
#
# @param pidfile
# @param name [String] an arbitrary name that might show up in STDOUT on errors
#
# Run this before attempting to start new processes that may use the same :pidfile:.
# If an old process is running on the pid found in the :pidfile:, exit 1. Otherwise,
# remove the stale :pidfile: if it exists.
#
function pid_guard() {
  declare pidfile="$1"