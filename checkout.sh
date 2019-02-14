#! /bin/sh

set -xe

git clone https://github.com/coolo/osc-plugin-factory.git
cd osc-plugin-factory
git checkout gitlab_experiments
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
#git merge -m 'm' origin/refactor_pkglistgen
python report-status.py -A $STAGING_API -p $STAGING_PROJECT -r standard -s pending

