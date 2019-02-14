#! /bin/sh

set -x

export PYTHONPATH=/usr/share/openSUSE-release-tools

if python -u ./rabbit-build.py -A $STAGING_API -p $STAGING_PROJECT -r standard; then
   # as the build id changed, we update the URL
   python ./report-status.py -A $STAGING_API -p $STAGING_PROJECT -r standard -s pending
else
   python ./report-status.py -A $STAGING_API -p $STAGING_PROJECT -r standard -s failure
   exit 1
fi

