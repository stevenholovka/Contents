#!/bin/bash

scriptname=$0
args=("$@")
argsCount=$#

# defaults
config=Release
defaultversion=1.0.1
version=$defaultversion
releasedir="Output/Releases"
apptype="Cleetwood"

pushd `dirname $0` > /dev/null
CURDIR=`pwd`
popd > /dev/null
CURVERFILE="${CURDIR}/../CurrentVersion.txt"
VERNUMFILE="${CURDIR}/../../Sources/VersionNumber.h"
UPDATESURLFILE="${CURDIR}/../FirmwareServerURL.txt"
DEVICECONFIGSDIR="${CURDIR}/../../../Devices"
DEVICESHEADERHID="${CURDIR}/../../Sources/SupportedDevicesHID.h"
DEVICESHEADERDFU="${CURDIR}/../../Sources/SupportedDevicesDFU.h"
FIRMWAREDIR="${CURDIR}/../../../Firmware/Latest"
OUTPUTPATHFILE="${CURDIR}/../OutputPath.txt"
IMAGESDIR="${CURDIR}/../../images"
DEVICECONNECTIONIMGMAC="connect_usb_mac.png"

usage()
{
    echo
    echo "Usage: $scriptname <params>"
    echo "         --config=CONFIG             'release' or 'debug' or 'all'"
    echo "         --version=VERSION           set version number, must be formatted as following: major.minor.build"
    echo "         --increase-build            increase build number"
    echo "         --increase-minor            increase minor version number"
    echo "         --increase-major            increase major version number"
    echo "         --reset-version             reset version to its default value (1.0.1)"
    echo "         --set-version               prompt to enter new version number"
    echo "         --show-version              show last saved version number"
    echo "         --build                     build project"
    echo
    exit 1
}

capitalizef()
{
    local w=$1
    local f=${w:0:1}
    f=`echo -n $f | tr "[:lower:]" "[:upper:]"`
    w="$f${w:1}"
    echo $w
}

print_version()
{
    echo "Version: ${version}"
}

load_version()
{
    if [ -f "${CURVERFILE}" ]; then
        version=`cat ${CURVERFILE}`
    else
        version=$defaultversion
    fi
    parse_version
}

load_updates_url()
{
    if [ -f "${UPDATESURLFILE}" ]; then
        updatesurl=`head -n 1 ${UPDATESURLFILE}`
    fi
}

save_version()
{
    echo -n $version > $CURVERFILE
}

update_version()
{
    version="$VersionMajor.$VersionMinor.$VersionBuild"
}

inc_val()
{
    local what=$1
    eval local ov=\$$what
    local nv=`expr ${ov} + 1`
    eval let \$what=\$nv
    update_version
    print_version
    save_version
}

parse_version()
{
    local verarr=`echo ${version} | tr "." " "`
    local cnt=0
    VersionBuild=0
    for v in $verarr; do
        if ! [[ "$v" =~ ^[0-9]+$ ]]; then
            echo "Invalid characters in version" && exit 1
        fi
        cnt=$((cnt+1))
        case $cnt in
            1) VersionMajor=$v ;;
            2) VersionMinor=$v ;;
            3) VersionBuild=$v ;;
        esac
    done
    if [ -n "${BUILD_NUMBER}" ]; then
        VersionBuild=${BUILD_NUMBER}
    fi
    if [ $cnt -lt 2 ]; then
        echo "Version must be properly formatted: major.minor[.build]"
        exit 1
    fi
    update_version
}

gen_version()
{
    cat > "${VERNUMFILE}" << EOF
#ifndef __VERION_NUMBER_H__
#define __VERION_NUMBER_H__
#define VER_DEFINED
#define VER_MAJOR ${VersionMajor}
#define VER_MINOR ${VersionMinor}
#define VER_BUILD ${VersionBuild}
#endif
EOF
}

build()
{
    prepare
    local gccdefs=""
    if [ -n "${updatesurl}" ]; then
        gccdefs="UPDATESURL=\\\"${updatesurl}\\\""
    fi
    gen_version
    for configname in $config; do
        configname=$(capitalizef $configname)
        echo
        echo "Building product:"
        echo "   Configuration: ${apptype}-${configname}"
        echo "   Version      : ${version}"
        echo
        local outdir="${CURDIR}/${releasedir}/${version}"
        echo "${outdir}" > "${OUTPUTPATHFILE}"
        local outpath="${outdir}/Sequoia_${configname}_${version}${PRODUCTSUFFIX}.dmg"
        export BuildMakeDmg=1
        export BuildVersionNumber=${version}
        export BuildOutputPath=${outpath}
        if [ -n "${DEVICENAME}" ]; then
            export OVERRIDE_PRODUCT_NAME="${DEVICENAME}"
            gccdefs="$gccdefs SUPPORT_URL_LINK=\\\"${DEVICESUPPORTURL}\\\" TARGET_PRODUCT_NAME=\"${DEVICENAME}\""
        fi
        if [ -n "${FWTMPDIR}" ]; then
            export FWINPUTDIR="${FWTMPDIR}"
        fi
        xcodebuild -scheme ${apptype} -configuration ${apptype}-${configname} clean
        xcodebuild -scheme ${apptype} -configuration ${apptype}-${configname} GCC_PREPROCESSOR_DEFINITIONS="\$GCC_PREPROCESSOR_DEFINITIONS $gccdefs"
        if [ $? -ne 0 ]; then
            echo "FAILED TO BUILD ${apptype}-${configname}!"
            exit 1
        fi
    done
}

iscraterlake=false

xmlvalue()
{
    local out=$(xpath $1 $2 2>/dev/null)
    if [ -z "$out" ]; then
       exit 1
    fi
    echo $out | sed -e 's/ *[a-zA-Z0-9_]*\=\"\(.*\)\"/\1/g'
}

DEVICENAME=""
DEVICESUPPORTURL=""
FWTMPDIR=""
PRODUCTSUFFIX=""

prepare()
{
    local deviceids="*"
    if [ -n "${DEVICECONFIG}" ]; then
        deviceids=${DEVICECONFIG}
    fi
    if [ "$deviceids" == "*" ] || [ "$deviceids" == "all" ]; then
        iscraterlake=true
        apptype="CraterLake"
        local files=$(find "$DEVICECONFIGSDIR" -iname "*.xml")
        deviceids=""
        for conf in $files; do
            conf=${conf##*/}
            conf=${conf%%.*}
            deviceids="${deviceids},${conf}"
        done
    fi

    > $DEVICESHEADERHID
    > $DEVICESHEADERDFU

    local overridedevice=true
    IFS=',' read -a deviceidslist <<< "$deviceids"
    for confid in ${deviceidslist[@]}; do
        if [ -n "$confid" ]; then
            local configpath="${DEVICECONFIGSDIR}/${confid}.xml"
            if [ ! -f "${configpath}" ]; then
                echo "Device configuration file does not exist: ${configpath}"
                exit 1
            fi
            echo $configpath
            local DEVID=$(xmlvalue "$configpath" "/device/@id")
            local DEVNAME=$(xmlvalue "$configpath" "/device/@name")
            local DEVHIDVID=$(xmlvalue "$configpath" "/device/hid/@vid")
            local DEVHIDPID=$(xmlvalue "$configpath" "/device/hid/@pid")
            local DEVDFUVID=$(xmlvalue "$configpath" "/device/dfu/@vid")
            local DEVDFUPID=$(xmlvalue "$configpath" "/device/dfu/@pid")
            local DEVSUPPORTLINK=$(xmlvalue "$configpath" "/device/links/@support")
            local DEVCONNIMGPC=$(xmlvalue "$configpath" "/device/image/@connection_pc")
            local DEVCONNIMGMAC=$(xmlvalue "$configpath" "/device/image/@connection_mac")
            local FWVERSHIFT=$(xmlvalue "$configpath" "/device/@fwvershift")
            local ISNJCDEVICE=$(xmlvalue "$configpath" "/device/@isNJCDevice")

            local DeviceFWPath="${FIRMWAREDIR}/${DEVID}"
            local DeviceFWManifest="${DeviceFWPath}/FWData.xml"
            if [ ! -f "${DeviceFWManifest}" ]; then
                echo "Firmware manifest does not exist: ${DeviceFWManifest}"
                exit 1
            fi
            local DeviceFWVersion=$(xmlvalue "$DeviceFWManifest" "/firmwaremanifest/device/fw/@version")
            if [ -z "${FWTMPDIR}" ]; then
                FWTMPDIR=$(mktemp -d -t "fwdir")
            fi
            cp -R "${DeviceFWPath}" "${FWTMPDIR}/"

#
#	For Sequoia, we want to keep the messaging as generic as possible, because of the need
#	to support multiple target speakers.
#

#            if ! $iscraterlake; then
#                PRODUCTSUFFIX="${PRODUCTSUFFIX}_${DEVID}_${DeviceFWVersion}"
#                if $overridedevice; then
#                    overridedevice=false
#                    DEVICESUPPORTURL=${DEVSUPPORTLINK}
#                    DEVICENAME=${DEVNAME}
#                    if [ -z "$DEVCONNIMGMAC" ]; then
#                        DEVCONNIMGMAC=${DEVCONNIMGPC}
#                    fi
#                    echo "${DEVCONNIMGMAC}"
#                    if [ -n "$DEVCONNIMGMAC" ]; then
#                        cp -f "${DEVICECONFIGSDIR}/${DEVCONNIMGMAC}" "${IMAGESDIR}/${DEVICECONNECTIONIMGMAC}"
#                    else
#                        echo "There is no connection image defined for device ${DEVID}, using default."
#                    fi
#                fi
#            fi

            echo "{ ${DEVHIDVID}, ${DEVHIDPID}, true, \"${DEVID}\", DefaultVersionReport, DefaultDFUModeReport, ${FWVERSHIFT}, ${ISNJCDEVICE} }," >> $DEVICESHEADERHID
            echo "DeviceInfo(\"${DEVID}\", \"${DEVNAME}\", ${DEVDFUVID}, ${DEVDFUPID})," >> $DEVICESHEADERDFU
        fi
    done
    read -a BINLIST <<< $(find "${FIRMWAREDIR}" -name '*.bin')
    for BINFILE in "${BINLIST[@]}"
    do
        local BINBASE=($(basename "$BINFILE"))
    	cp "$BINFILE" "${FWTMPDIR}/$BINBASE"
    done
    echo "Version suffix: ${PRODUCTSUFFIX}"
}

cleanup()
{
    if [ -n "$FWTMPDIR" ] && [ -d "$FWTMPDIR" ]; then
        rm -rf "$FWTMPDIR"
    fi
}

trap cleanup EXIT

load_version
load_updates_url

dobuild=false
doresetversion=false
doincmajor=false
doincminor=false
doincbuild=false
dosetversion=false

for ((idx = 0; idx < argsCount; ++idx))
{
    arg=${args[$idx]}
    a=${arg:0:2}
    if [ "$a" == "--" ]; then
        aname=${arg%%=*}
        aname=${aname:2}
        aval=${arg#*=}
        case "$aname" in
            config)
                if [ "$aval" != "debug" ] && [ "$aval" != "release" ] && [ "$aval" != "all" ]; then
                    usage
                fi
                if [ "$aval" == "all" ]; then
                    config="debug release"
                else
                    config=$aval
                fi
            ;;

            version)
                version=$aval
                parse_version
                save_version
            ;;

            increase-build)
                doincbuild=true
            ;;

            increase-minor)
                doincminor=true
            ;;

            increase-major)
                doincmajor=true
            ;;

            reset-version)
                doresetversion=true
            ;;

            show-version)
                print_version
            ;;

            set-version)
                dosetversion=true
            ;;

            build)
                dobuild=true
            ;;

            *)
                usage
            ;;
        esac
    fi
}

if $doresetversion; then
    rm -f ${CURVERFILE}
    rm -f ${VERNUMFILE}
    version=$defaultversion
    parse_version
    print_version
fi

if $dosetversion; then
    read -e -p "Enter new version in format [major.minor.build]: " version
    if [ -n "$version" ]; then
        parse_version
        save_version
        print_version
    fi
fi

if $doincmajor; then
    inc_val "VersionMajor"
fi

if $doincminor; then
    inc_val "VersionMinor"
fi

if $doincbuild; then
    inc_val "VersionBuild"
fi

if $dobuild; then
    build
fi
