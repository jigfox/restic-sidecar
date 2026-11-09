#!/bin/sh

. ./init.inc.sh

restic snapshots --host ${RESTIC_HOST}
