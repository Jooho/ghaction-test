#!/usr/bin/env bash

# Note: The yaml in the body of the PR is used to feed inputs into the release workflow
# since there's no easy way to communicate information between the pr closing, and then triggering the
# release creation workflow.
# Therefore, take extra care when adding new code blocks in the PR body, or updating the existing one.
# Ensure any changes are compatible with the release_create workflow.

set -ex
set -o pipefail

echo "Retrieve the sha images from the resulting workflow (check quay.io for the digests)."
echo "Using [release-tools] generate a params.env and submit a new pr to vx.y+1.**x** branch."
echo "For images pulled from registry, ensure latest images are upto date"

BUILD_BRANCH_NAME="${TARGET_BRANCH}_build"
TARGET_REPOSITORY=${TARGET_COMPONENT}_REPOSITORY
TARGET_REPOSITORY_FULL=${TARGET_COMPONENT}_REPOSITORY_FULL

git config --global user.email "${GH_USER_EMAIL}"
git config --global user.name "${GH_USER_NAME}"
git clone https://${GH_USER_NAME}:${GH_TOKEN}@github.com/${GH_USER_NAME}/${TARGET_REPOSITORY}.git
cd ${TARGET_REPOSITORY}

git checkout -B ${BUILD_BRANCH_NAME}

echo "Created branch: ${BUILD_BRANCH_NAME}"

echo "serving-bot build: $(date)" > bot-build.txt
git add .
git commit -m "Trigger to build ${TARGET_COMPONENT} for ${TARGET_BRANCH}"
git push ${GH_USER_NAME} $BRANCH_NAME -f

# Used to feed inputs to release creation workflow.
# target_version is used as the GH TAG
tmp_config="/tmp/body-config.txt"
body_txt="/tmp/body-text.txt"
cp $CONFIG_TEMPLATE $tmp_config

var=${GH_ORG} yq -i '.odh_org=env(var)' $tmp_config
var=${TARGET_BRANCH} yq -i '.target_branch=env(var)' $tmp_config
var=${TARGET_COMPONENT} yq -i '.target_component=env(var)' $tmp_config


cat <<"EOF" > $body_txt
This is an automated PR to trigger ${TARGET_COMPONENT} openshift ci building new images
```yaml
<CONFIG_HERE>
```
EOF

sed -i "/<CONFIG_HERE>/{
    s/<CONFIG_HERE>//g
    r ${tmp_config}
}" $body_txt

pr_url=$(gh pr create \
  --repo https://github.com/${TARGET_REPOSITORY_FULL} \
  --body-file $body_txt \
  --title "Build ${TARGET_COMPONENT}:${TARGET_BRANCH} Images" \
  --head "${GH_USER_NAME}:$BRANCH_NAME" \
  --label "build-automation" \
  --base "${MINOR_RELEASE_BRANCH}")

echo "::notice:: PR successfully created: ${pr_url}"
