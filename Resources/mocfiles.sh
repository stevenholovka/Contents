#!/bin/bash

LISTFILE="${SRCROOT}/FilesToMoc"
OUTFOLDER="${SRCROOT}/../../Sources"
echo ${LISTFILE}
echo ${OUTFOLDER}
FILESLIST=$(cat $LISTFILE)
for FILENAME in $FILESLIST; do
    echo "Processing ${FILENAME}..."
    FIlENAMEWEXT=${FILENAME%.*}
    FILEEXT=${FILENAME##*.}
    MOCEDFILE="${OUTFOLDER}/${FIlENAMEWEXT}.inl.${FILEEXT}"
    moc "${OUTFOLDER}/${FILENAME}" "-o${MOCEDFILE}"
    if [ $? -ne 0 ]; then
        exit 1
    fi
done
exit 0
