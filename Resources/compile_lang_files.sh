#!/bin/bash

LANGFILESDIR=../../lang
LANGOUTDIR=$1
if [ "x${LANGOUTDIR}" == "x" ]; then
    LANGOUTDIR=${LANGFILESDIR}/compiled
fi

if [ ! -d "${LANGOUTDIR}" ]; then
    mkdir -p "${LANGOUTDIR}"
fi

FILESLIST="de-DE.ts en-US.ts es-ES.ts fr-FR.ts ja-JP.ts ko-KR.ts zh-CN.ts zh-TW.ts"
#FILESLIST="de-DE.ts en-US.ts es-ES.ts fr-FR.ts it-IT.ts ja-JP.ts ko-KR.ts nb-NO.ts nl-NL.ts ru-RU.ts sv-SE.ts zh-CN.ts zh-TW.ts"

pushd ${LANGFILESDIR}
lrelease ${FILESLIST}
echo Moving language files to: ${LANGOUTDIR}
mv *.qm "${LANGOUTDIR}/"
popd

echo Creating *.lproj dirs
for LANG in ${FILESLIST}
do
LANGNAME=$(echo ${LANG} | cut -f1 -d'.')
DIRNAME="${LANGOUTDIR}/${LANGNAME}.lproj"
if [ ! -d "${DIRNAME}" ]; then
mkdir "${DIRNAME}"
fi
done
