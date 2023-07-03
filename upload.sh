#!/usr/bin/env bash

set -e
shopt -s nullglob

echo "Installing package cloud gem..."
sudo gem install --no-document package_cloud

echo "REPO=${REPO}"
echo "SOURCE=${SOURCE}"
echo "PACKAGECLOUD_RPM_DISTRIB=${PACKAGECLOUD_RPM_DISTRIB}"
echo "PACKAGECLOUD_DEB_DISTRIB=${PACKAGECLOUD_DEB_DISTRIB}"

if [ "$REPO" = "" ]; then
    echo "No REPO provided!"
    exit 1
elif [ "$SOURCE" = "" ]; then 
    echo "No SOURCE provided!"
    exit 1
fi

upload() {
        echo "Uploading ${PACKAGE_NAME} to ${UPLOAD_PATH}."
        package_cloud push ${UPLOAD_PATH} ${PACKAGE_NAME}
}

upload_file() {
    if [ "$DISTRIBUTIONS" = "" ]; then
        UPLOAD_PATH="${REPO}"
        upload
    else
        for distrib in $DISTRIBUTIONS; do 
            UPLOAD_PATH="${REPO}/${distrib}"
            upload
        done
    fi
}

upload_folder() {
    DISTRIBUTIONS="${PACKAGECLOUD_DEB_DISTRIB}"
    for deb in ${SOURCE}/*.deb; do
        PACKAGE_NAME=$deb
        upload_file
    done

    DISTRIBUTIONS="${PACKAGECLOUD_RPM_DISTRIB}"
    for rpm in ${SOURCE}/*.rpm; do
        PACKAGE_NAME=$rpm
        upload_file
    done
}

if [ -d "$SOURCE" ]; then
    upload_folder
else 
    if [ "${SOURCE##*.}" = "rpm" ]; then DISTRIBUTIONS="${PACKAGECLOUD_RPM_DISTRIB}"; fi
    if [ "${SOURCE##*.}" = "deb" ]; then DISTRIBUTIONS="${PACKAGECLOUD_DEB_DISTRIB}"; fi
    PACKAGE_NAME="${SOURCE}"
    upload_file
fi
