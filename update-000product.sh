#! /bin/sh

set -x

export PYTHONPATH=/usr/share/openSUSE-release-tools

if /usr/bin/osrt-pkglistgen -A $STAGING_API update_and_solve --staging $STAGING_PROJECT; then
  python ./report-status.py -A $STAGING_API -p $STAGING_PROJECT -r standard -s success
else
  python ./report-status.py -A $STAGING_API -p $STAGING_PROJECT -r standard -s failure
  exit 1
fi

