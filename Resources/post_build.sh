#!/bin/bash

SIGNING_IDENTITY="Developer ID Application: Logitech Inc."
makedmg=false
isrelease=false

if [ "x${BuildMakeDmg}" == "x1" ]; then
    makedmg=true
fi

echo "$CONFIGURATION" | grep -i release
if [ $? -eq 0 ]; then
    isrelease=true
    makedmg=true
fi

APP_DIR=${TARGET_BUILD_DIR}/${WRAPPER_NAME}
sh "${SRCROOT}/fixlibs.sh" "${APP_DIR}"
if [ $? -ne 0 ]; then
exit 1
fi

if ! $makedmg; then
    exit 0
fi

set -e

#fwoutdir="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}/firmware"
#if [ -z "${FWINPUTDIR}" ]; then
#    FWINPUTDIR="${SRCROOT}/../../../Firmware/Latest/"
#fi
#if [ -d "${fwoutdir}" ]; then
#    rm -rf "${fwoutdir}"
#fi
#mkdir -p "${fwoutdir}"
#cp -f -R "${FWINPUTDIR}/" "${fwoutdir}"

find "${TARGET_BUILD_DIR}" -iname ".MySCMServerInfo" -print0 | xargs -0 rm -f

FINAL_PRODUCT_NAME=${PRODUCT_NAME}
if [ -n "${OVERRIDE_PRODUCT_NAME}" ]; then
    FINAL_PRODUCT_NAME="${OVERRIDE_PRODUCT_NAME} Update Assistant"
    APP_DIR=${TARGET_BUILD_DIR}/${FINAL_PRODUCT_NAME}.${WRAPPER_EXTENSION}
    if [ -d "${APP_DIR}" ]; then
        rm -rf "${APP_DIR}"
    fi
    mv "${TARGET_BUILD_DIR}/${WRAPPER_NAME}" "${APP_DIR}"
    mv "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}" "${APP_DIR}/Contents/MacOS/${FINAL_PRODUCT_NAME}"
fi

infoplistpath="${APP_DIR}/Contents/Info.plist"
PListBuddy="/usr/libexec/PlistBuddy"
if [ -n "${BuildVersionNumber}" ]; then
    ${PListBuddy} -c "Set CFBundleVersion ${BuildVersionNumber}" "$infoplistpath"
    ${PListBuddy} -c "Set CFBundleShortVersionString ${BuildVersionNumber}" "$infoplistpath"
fi
${PListBuddy} -c "Set CFBundleDisplayName ${FINAL_PRODUCT_NAME}" "$infoplistpath"
${PListBuddy} -c "Set CFBundleExecutable ${FINAL_PRODUCT_NAME}" "$infoplistpath"
${PListBuddy} -c "Set CFBundleName ${FINAL_PRODUCT_NAME}" "$infoplistpath"
appid="com.logitech.ue,${FINAL_PRODUCT_NAME// /-}"
${PListBuddy} -c "Set CFBundleIdentifier ${appid}" "$infoplistpath"

dmgfile="${TARGET_BUILD_DIR}/${FINAL_PRODUCT_NAME}.dmg"
#tmppath="${APP_DIR}.tmp"
#rm -rf "$tmppath"
#mv "$APP_DIR" "$tmppath"
#ditto --rsrc --arch i386 "${tmppath}" "${APP_DIR}"
#rm -rf "$tmppath"
#strip -x

set +e
security find-identity -v | grep "${SIGNING_IDENTITY}"
if [ $? -eq 0 ]; then
# codesign --verbose --force --sign "${SIGNING_IDENTITY}" "${APP_DIR}/Contents/Frameworks/QtCore.framework"
# codesign --verbose --force --sign "${SIGNING_IDENTITY}" "${APP_DIR}/Contents/Frameworks/QtNetwork.framework"
# codesign --verbose --force --sign "${SIGNING_IDENTITY}" "${APP_DIR}/Contents/Frameworks/QtXml.framework"
# codesign --verbose --force --sign "${SIGNING_IDENTITY}" "${APP_DIR}/Contents/Frameworks/QtGui.framework"
# codesign --verbose --force --sign "${SIGNING_IDENTITY}" "${APP_DIR}/Contents/Frameworks/QtWidgets.framework"
codesign --verbose --force --sign "${SIGNING_IDENTITY}" "${APP_DIR}/Contents/Frameworks/DFUEngine.framework"
codesign --verbose --force --sign "${SIGNING_IDENTITY}" "${APP_DIR}/Contents/Frameworks/LWxHIDManager-embedded.framework"
codesign --verbose --deep --sign "${SIGNING_IDENTITY}" "${APP_DIR}"
fi
set -e

hdiutil create -srcfolder "${APP_DIR}" -volname "${FINAL_PRODUCT_NAME}" -format UDZO -ov "$dmgfile"
relpath="${BuildOutputPath}"
if [ -z "$relpath" ]; then
    releasedir="$CONFIGURATION"
    relpath="${SRCROOT}/Output/Xcode/${releasedir}/${FINAL_PRODUCT_NAME}.dmg"
fi
reldir=$(dirname "$relpath")
if [ ! -d "$reldir" ]; then
    mkdir -p "$reldir"
fi
cp -f "$dmgfile" "$relpath"
