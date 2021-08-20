#!/bin/bash

app=$1
appbin=${app##*/}
appbin=${appbin%.app}
apppath="$app/Contents/MacOS/$appbin"
fpath="$app/Contents/Frameworks"
flist=$(ls -1 "$fpath")

# function changes loading paths of embedded dependencies for given binary
function fixpathsint {
  local fixwhat=$1
  dependencies=$(otool -L "$fixwhat" | awk 'BEGIN { i=0; } { s=substr($1,1,1); if (i!=0 && s!="/" && s!="@") { print $1; } i++;  }')
  for dep in $dependencies; do
    local pathtoreplace="${dep##(*}"
    install_name_tool -change "$pathtoreplace" "@executable_path/../Frameworks/$pathtoreplace" "$fixwhat"
  done
  strip -x "$fixwhat"
}


# removing "Headers" folders from frameworks
# fixing identification names and loading paths of frameworks

pushd "$fpath"

find ./ -type d -iname "headers" -print0 | xargs -0 rm -rf

for frameworkname in $flist; do
  shortname=${frameworkname%.framework}
  thispath="$frameworkname/Versions/Current/$shortname"
  chmod +w "${thispath}"
  install_name_tool -id "@executable_path/../Frameworks/$thispath" "$thispath"
done

for frameworkname in $flist; do
  shortname=${frameworkname%.framework}
  thispath="$frameworkname/Versions/Current/$shortname"
  fixpathsint "$thispath"
done

popd


# fixing frameworks loading paths in our app binary

fixpathsint "$apppath"


# copying Qt plugins and fixing their dependencies loading paths

macdeployqt "$app"
