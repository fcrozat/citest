echo '---' > sp1-stagings.gocd.yaml
echo 'format_version: 3' >> sp1-stagings.gocd.yaml
echo 'pipelines:' >> sp1-stagings.gocd.yaml

cat >>  sp1-stagings.gocd.yaml <<EOF
  SLE15.SP1.Stagings.RelPkgs:
    environment_variables:
      OSC_CONFIG: /home/go/config/oscrc-staging-bot
    group: SLE15.SP1.Stagings
    lock_behavior: unlockWhenFinished
    timer:
      spec: 0 */10 * ? * *
      only_on_changes: false
    materials:
      scripts:
        git: https://github.com/coolo/citest.git
    stages:
    - Generate.Release.Package:
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
              - script: /usr/bin/osrt-pkglistgen -A https://api.suse.de update_and_solve
                 --staging SUSE:SLE-15-SP1:GA:Staging:$staging
                 --only-release-packages --force
EOF
done

for staging in $sles_stagings; do
repofile=SUSE:SLE-15-SP1:GA:Staging:$staging'_-_standard.yaml'
cat >> sp1-stagings.gocd.yaml <<EOF
  "SLE15.SP1.Staging.$staging":
    environment_variables:
      STAGING_PROJECT: SUSE:SLE-15-SP1:GA:Staging:$staging
      STAGING_API: https://api.suse.de
      OSC_CONFIG: /home/go/config/oscrc-staging-bot
      PYTHONPATH: /usr/share/openSUSE-release-tools
    group: SLE15.SP1.Stagings
    lock_behavior: unlockWhenFinished
    materials:
      stagings:
        git: git://botmaster.suse.de/suse-repos.git
        auto_update: true
        whitelist:
          - $repofile
    stages:
    - "Check.Build.Succeeds":
        resources:
          - staging-bot
        tasks:
          - script: |-
              git clone https://github.com/coolo/citest.git
              cd citest
              python ./report-status.py -A \$STAGING_API -p \$STAGING_PROJECT -r standard -s pending
              python ./verify-repo-built-successful.py -A \$STAGING_API -p \$STAGING_PROJECT -r standard

    - "Update.000product":
        resources:
          - repo-checker
        tasks:
          - script: |-
              git clone https://github.com/coolo/citest.git
              cd citest

              if /usr/bin/osrt-pkglistgen --debug -A \$STAGING_API update_and_solve --staging \$STAGING_PROJECT --force; then
                python ./report-status.py -A \$STAGING_API -p \$STAGING_PROJECT -r standard -s success
              else
                python ./report-status.py -A \$STAGING_API -p \$STAGING_PROJECT -r standard -s failure
                exit 1
              fi
EOF

done

echo 'format_version: 3' > pkglistgen_staging.gocd.yaml
echo 'pipelines:' >> pkglistgen_staging.gocd.yaml

cat >>  pkglistgen_staging.gocd.yaml <<EOF
  Factory.Stagings.RelPkgs:
    environment_variables:
      OSC_CONFIG: /home/go/config/oscrc-staging-bot
    group: Factory.pkglistgen
    lock_behavior: unlockWhenFinished
    timer:
      spec: 0 */10 * ? * *
      only_on_changes: false
    materials:
      scripts:
        git: https://github.com/coolo/citest.git
    stages:
    - Generate.Release.Package:
        approval: manual
        jobs:
EOF

factory_stagings="A B C D E F G H I J K L M N O Gcc7"
for staging in $factory_stagings; do

  cat >> pkglistgen_staging.gocd.yaml <<EOF
            "Staging.$staging":
              resources:
                - repo-checker
              tasks:
                - script: /usr/bin/osrt-pkglistgen -A https://api.opensuse.org update_and_solve
                   --staging openSUSE:Factory:Staging:$staging
                   --only-release-packages --force
EOF
done

for staging in $factory_stagings; do

repofile=openSUSE:Factory:Staging:$staging'_-_standard.yaml'
cat >> pkglistgen_staging.gocd.yaml <<EOF
  "Factory.Staging.$staging":
    environment_variables:
      STAGING_PROJECT: openSUSE:Factory:Staging:$staging
      STAGING_API: https://api.opensuse.org
      OSC_CONFIG: /home/go/config/oscrc-staging-bot
      PYTHONPATH: /usr/share/openSUSE-release-tools
    group: Factory.pkglistgen
    lock_behavior: unlockWhenFinished
    materials:
      stagings:
        git: git://botmaster.suse.de/opensuse-repos.git
        auto_update: true
        destination: repos
        whitelist:
          - $repofile
      scripts:
        git: https://github.com/openSUSE/openSUSE-release-tools.git
        auto_update: true
        destination: scripts
        whitelist:
          - DO_NOT_TRIGGER
      citest:
        git: https://github.com/coolo/citest.git
        auto_update: true
        destination: citest
        whitelist:
          - DO_NOT_TRIGGER
    stages:
    - Checks:
        jobs:
          Check.Build.Succeeds:
            resources:
              - staging-bot
            tasks:
              - script: |-
                  python ./citest/verify-repo-built-successful.py -A \$STAGING_API -p \$STAGING_PROJECT -r standard

          Repo.Checker:
            environment_variables:
              OSC_CONFIG: /home/go/config/oscrc-repo-checker
            resources:
              - repo-checker
            tasks:
              - script: |-
                  ./scripts/staging-installcheck.py -A \$STAGING_API -p openSUSE:Factory -s \$STAGING_PROJECT

    - Update.000product:
        resources:
          - repo-checker
        tasks:
          - script: |-
              /usr/bin/osrt-pkglistgen --debug -A \$STAGING_API update_and_solve --staging \$STAGING_PROJECT --force

    - Enable.images.repo:
       resources:
         - staging-bot
       tasks:
         - script: |-
             osc -A \$STAGING_API api -X POST "/source/\$STAGING_PROJECT?cmd=remove_flag&repository=images&flag=build"

EOF

done

cat >>  pkglistgen_staging.gocd.yaml <<EOF
  Leap.Stagings.RelPkgs:
    environment_variables:
      OSC_CONFIG: /home/go/config/oscrc-staging-bot
    group: Leap.pkglistgen
    lock_behavior: unlockWhenFinished
    timer:
      spec: 0 */10 * ? * *
      only_on_changes: false
    materials:
      scripts:
        git: https://github.com/coolo/citest.git
    stages:
    - Generate.Release.Package:
        approval: manual
        jobs:
EOF

leap_stagings="A B C D E"
for staging in $leap_stagings; do

cat >> pkglistgen_staging.gocd.yaml <<EOF
          "Staging.$staging":
            resources:
              - repo-checker
            tasks:
              - script: /usr/bin/osrt-pkglistgen -A https://api.opensuse.org update_and_solve
                 --staging openSUSE:Leap:15.1:Staging:$staging
                 --only-release-packages --force
EOF
done

for staging in $leap_stagings; do
repofile=openSUSE:Leap:15.1:Staging:$staging'_-_standard.yaml'
cat >> pkglistgen_staging.gocd.yaml <<EOF
  "Leap.Staging.$staging":
    environment_variables:
      STAGING_PROJECT: openSUSE:Leap:15.1:Staging:$staging
      STAGING_API: https://api.opensuse.org
      OSC_CONFIG: /home/go/config/oscrc-staging-bot
      PYTHONPATH: /usr/share/openSUSE-release-tools
    group: Leap.pkglistgen
    lock_behavior: unlockWhenFinished
    materials:
      stagings:
        git: git://botmaster.suse.de/opensuse-repos.git
        auto_update: true
        destination: repos
        whitelist:
          - $repofile
      scripts:
        git: https://github.com/openSUSE/openSUSE-release-tools.git
        auto_update: true
        destination: scripts
        whitelist:
          - DO_NOT_TRIGGER
      citest:
        git: https://github.com/coolo/citest.git
        auto_update: true
        destination: citest
        whitelist:
          - DO_NOT_TRIGGER
    stages:
    - Checks:
        jobs:
          Check.Build.Succeeds:
            resources:
              - staging-bot
            tasks:
              - script: |-
                  python ./citest/verify-repo-built-successful.py -A \$STAGING_API -p \$STAGING_PROJECT -r standard

          Repo.Checker:
            environment_variables:
              OSC_CONFIG: /home/go/config/oscrc-repo-checker
            resources:
              - repo-checker
            tasks:
              - script: |-
                  ./scripts/staging-installcheck.py -A \$STAGING_API -p openSUSE:Leap:15.1 -s \$STAGING_PROJECT

    - "Update.000product":
        resources:
          - repo-checker
        tasks:
          - script: |-
              /usr/bin/osrt-pkglistgen --debug -A \$STAGING_API update_and_solve --staging \$STAGING_PROJECT --force
EOF

done
