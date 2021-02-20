#!/bin/sh -l

set -eu

mkdir /dist /build

REPOSITORY_NAME=$(echo "${GITHUB_REPOSITORY}" | awk -F / '{print $2}' | sed -e "s/:refs//")
VERSION=$GITHUB_REF

echo "${REPOSITORY_NAME} ${INPUT_VERSION} ${INPUT_ADMINPLUGIN}"

# Download Grav @ specific version and get it ready for the Skeleton
cd /build
curl --write-out '%{http_code}' --silent --location https://getgrav.org/download/core/grav/${INPUT_VERSION} > grav.zip;
unzip -q grav.zip
rm -rf grav.zip

cd grav

rm -rf user
cp -Rf $GITHUB_WORKSPACE user
bin/grav install

zip -q -x "*.git/*" -x "*.github/workflows/*" -x *yarn.lock* -x *.gitignore* -x *.editorconfig* -x *.DS_Store* -x *hebe.json* -x *.dependencies* -x *.travis.yml* -r "/dist/${REPOSITORY_NAME}-${VERSION}.zip" /build

ls -la .
ls -la /dist
ls -la /build
# ls -la $GITHUB_WORKSPACE
# zip -q -x "*.git/*" -x "*.github/workflows/*" -x *yarn.lock* -x *.gitignore* -x *.editorconfig* -x *.DS_Store* -x *hebe.json* -x *.dependencies* -x *.travis.yml* -r $1 $2