#!/bin/bash
# Double-click this on a Mac.
# Everything it does lives in .reprise/menu -- this file just opens it.
cd "$(dirname "$0")" || exit 1
exec bash ./.reprise/menu
