#!/bin/sh -l

set -eu

# Prepping files will reside in /build
# Output zip packages will reside in /dist
mkdir /dist /build

# Variables prepping
REPOSITORY_NAME=$(echo "${GITHUB_REPOSITORY}" | awk -F / '{print $2}' | sed -e "s/:refs//")
VERSION=${SKELETON_VERSION:-$GITHUB_REF}
VERSION=$(echo "${VERSION}" | sed -e "s/refs\/heads\///" | sed -e "s/refs\/tags\///")
SILENT='-q'
CURL_SILENT='--silent'

if $INPUT_VERBOSE; then
    SILENT=
    CURL_SILENT=
fi

# Download Grav @ specific version and get it ready for the Skeleton
cd /build
curl --write-out '%{http_code}' ${CURL_SILENT} --location https://getgrav.org/download/core/grav/${INPUT_VERSION} > grav.zip;
unzip ${SILENT} grav.zip
rm -rf grav.zip

cd grav

# Install the skeleton user folder, keeping core's user/.htaccess (the
# defense-in-depth deny rules) unless the skeleton ships its own
if [ -f user/.htaccess ]; then
    cp user/.htaccess /build/user.htaccess
fi
rm -rf user
cp -Rf $GITHUB_WORKSPACE user
if [ ! -f user/.htaccess ] && [ -f /build/user.htaccess ]; then
    cp /build/user.htaccess user/.htaccess
fi
# Grav refuses to run without these, and a skeleton repo can leave one out
mkdir -p user/accounts user/config user/data user/pages user/plugins user/themes
bin/grav install ${SILENT}

# Grav writes the site's private key (user/config/security-private.php) the
# first time anything boots it, and installing dependencies can. A key built
# into the package would be the same on every site installed from it, so none
# ships: Grav generates one for each site on its first request.
drop_site_keys() {
    find user -name security-private.php -delete
}
drop_site_keys

USER_EXCLUDE=$INPUT_EXCLUDE
FILENAME_VERSION="-${VERSION}"

if [ ! -z "$INPUT_EXCLUDE" ]; then
    USER_EXCLUDE=$(echo "-x ${USER_EXCLUDE// / -x }")
fi

if ! $INPUT_FILENAME_VERSION; then
    FILENAME_VERSION=''
fi

# Create a package of the skeleton (w/o admin)
zip ${SILENT} -x "*.git/*" -x "*.github/*" -x "cache/compiled/*" -x *yarn.lock* -x *.gitignore* -x *.editorconfig* -x *.DS_Store* -x *hebe.json* -x *.dependencies* -x *.travis.yml* -x "*security-private.php" $USER_EXCLUDE -r "/dist/${REPOSITORY_NAME}${FILENAME_VERSION}.zip" .

# If option enabled, also create a package with admin included
if $INPUT_ADMIN; then
    bin/gpm install admin -y ${SILENT}
    drop_site_keys
    zip ${SILENT} -x "*.git/*" -x "*.github/*" -x "cache/compiled/*" -x *yarn.lock* -x *.gitignore* -x *.editorconfig* -x *.DS_Store* -x *hebe.json* -x *.dependencies* -x *.travis.yml* -x "*security-private.php" $USER_EXCLUDE -r "/dist/${REPOSITORY_NAME}+admin${FILENAME_VERSION}.zip" .
fi

# Finally make the dist packages available in the workspace
mv /dist $GITHUB_WORKSPACE

# When in verbose mode, output a list of installed plugins/themes and final /build folder
if $INPUT_VERBOSE; then
    ls -la user/plugins
    ls -la user/themes
    ls -la $GITHUB_WORKSPACE/dist
fi
