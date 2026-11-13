#!/usr/bin/env bash
set -euo pipefail
_build/prod/rel/nook/bin/nook eval 'Nook.Release.migrate()'
exec _build/prod/rel/nook/bin/nook start
