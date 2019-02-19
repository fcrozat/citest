echo 'format_version: 3' > sp1-stagings.gocd.yaml
echo 'pipelines:' >> sp1-stagings.gocd.yaml

cat >>  sp1-stagings.gocd.yaml <<EOF
  "SLE15.SP1.Stagings.Release.Packages":
    environment_variables:
      OSC_CONFIG: /home/go/.oscrc-staging-bot
    group: SLE15.SP1.Stagings
    lock_behavior: unlockWhenFinished
    materials:
      scripts:
        git: https://github.com/coolo/citest.git
    timer:
      spec: 0 */10 * ? * *
      only_on_changes: false
    stages:
      - "Generate.Release.Package":
        approval: manual
        jobs:
EOF

sles_stagings="A B C D E F G H S V Y"
for staging in $sles_stagings; do

cat >> sp1-stagings.gocd.yaml <<EOF
          "SLE.15.SP1.Staging.$staging":
            resources:
              - repo-checker
            tasks:
            - script: /usr/bin/osrt-pkglistgen -A https://api.suse.de update_and_solve --staging SUSE:SLE-15-SP1:GA:Staging:$staging --only-release-packages --force
EOF
done

for staging in $sles_stagings; do
cat >> sp1-stagings.gocd.yaml <<EOF
  "SLE15.SP1.Staging.$staging":
    environment_variables:
      STAGING_PROJECT: SUSE:SLE-15-SP1:GA:Staging:$staging
      STAGING_API: https://api.suse.de
      OSC_CONFIG: /home/go/.oscrc-staging-bot
    group: SLE15.SP1.Stagings
    lock_behavior: unlockWhenFinished
    materials:
      scripts:
        git: https://github.com/coolo/citest.git
    stages:
      - "Check.Build.Succeeds":
          jobs:
            "Wait.For.Build":
              resources:
                - staging-bot
              tasks:
              - script: |-
                  export PYTHONPATH=/usr/share/openSUSE-release-tools
                  python ./report-status.py -A \$STAGING_API -p \$STAGING_PROJECT -r standard -s pending

                  if python -u ./rabbit-build.py -A \$STAGING_API -p \$STAGING_PROJECT -r standard; then
                     ## as the build id changed, we update the URL
                     python ./report-status.py -A \$STAGING_API -p \$STAGING_PROJECT -r standard -s pending
                  else
                     python ./report-status.py -A \$STAGING_API -p \$STAGING_PROJECT -r standard -s failure
                     exit 1
                  fi
      - "Update.000product":
          jobs:
            "Run.Pkglistgen":
              resources:
                - repo-checker
              tasks:
              - script: |-
                  export PYTHONPATH=/usr/share/openSUSE-release-tools

                  if /usr/bin/osrt-pkglistgen --debug -A \$STAGING_API update_and_solve --staging \$STAGING_PROJECT; then
                    python ./report-status.py -A \$STAGING_API -p \$STAGING_PROJECT -r standard -s success
                  else
                    python ./report-status.py -A \$STAGING_API -p \$STAGING_PROJECT -r standard -s failure
                    exit 1
                  fi
EOF

done

echo 'format_version: 3' > pkglistgen_staging.gocd.yaml
echo 'pipelines:' >> pkglistgen_staging.gocd.yaml

for staging in A B C D E F G H I J K L M N O; do

cat >> pkglistgen_staging.gocd.yaml <<EOF

  Pkglistgen.Factory_Staging.$staging:
    group: openSUSE.pkglistgen
    lock_behavior: unlockWhenFinished
    environment_variables:
      OSC_CONFIG: /home/go/.oscrc-staging-bot
    timer:
      spec: 0 */30 * ? * *
      only_on_changes: false
    materials:
      git:
        git: https://github.com/coolo/citest.git
    stages:
    - pkglistgen:
        approval: manual
        jobs:
          openSUSE_Factory:
            resources:
            - repo-checker
            tasks:
            - script: /usr/bin/osrt-pkglistgen -A https://api.opensuse.org update_and_solve --staging openSUSE:Factory:Staging:$staging --force
EOF
done
