echo 'format_version: 3' > ci.gocd.yaml
echo 'pipelines:' >> ci.gocd.yaml
for staging in A B C D E F G H S V Y; do

cat >> ci.gocd.yaml <<EOF
  "SLE15.SP1.Staging.$staging":
    environment_variables:
      STAGING_PROJECT: SUSE:SLE-15-SP1:GA:Staging:$staging
      STAGING_API: https://api.suse.de
    group: SLE15.SP1.Stagings
    materials:
      scripts:
        git: https://github.com/coolo/citest.git
    stages:
      - "Generate.Release.Package":
          approval: manual
          jobs:
            "Run.Pkglistgen":
              resources:
                - repo-checker
              tasks:
                - exec:
                    command: ./generate-release-pkg.sh
      - "Check.Build.Succeeds":
          jobs:
            "Wait.For.Build":
              tasks:
                - exec:
                    command: ./check-build.sh
      - "Update.000product":
          jobs:
            "Run.Pkglistgen":
              resources:
                - repo-checker
              tasks:
                - exec:
                    command: ./update-000product.sh
EOF

done
