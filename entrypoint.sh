#!/bin/bash
set -e
set -o pipefail

/usr/local/bin/setup-credentials-helper.sh

exec "$@"
