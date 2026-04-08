artifact_name="${PACKAGE_NAME}_macos_${ARCHITECTURE}"
# dependencies that shouldn't be installed here, because they should already be present on the target system
unwanted_deps=(openssl)
# create directories for artifacts
mkdir -p ${WORKSPACE_DIR}/$artifact_name/include
mkdir -p ${WORKSPACE_DIR}/$artifact_name/lib
# install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
# remove unnecessary casks, since sometimes they can break things
caskroom=$(brew --caskroom)
rm -rf "${caskroom:?}"/*
# get the latest version of the package and check if it matches the version provided in the tag
real_version="v$(brew info $PACKAGE_NAME | tail -n +1 | awk 'BEGIN {FS="[ ,]";} NR==1 {print $4}')"
if [[ ! $EXPECTED_VERSION =~ ^($real_version|"no check")$ ]]; then
  echo "Version passed via tag: $EXPECTED_VERSION not matching version to be installed: $real_version"
  exit 1
fi
# uninstall all packages that are already installed, since only the installed package
# and it's dependencies are needed
for pkg in $(brew list); do
  brew uninstall --ignore-dependencies --force $pkg
done
# install package
brew install $PACKAGE_NAME
# uninstall unwanted deps
for pkg in "${unwanted_deps[@]}"; do
  if brew list | grep -E "^${pkg}($|@)"; then
    brew uninstall --ignore-dependencies --force $pkg
  fi
done
# copy the artifacts
cp -r "$(brew --prefix)"/include/* ${WORKSPACE_DIR}/$artifact_name/include

cd "$(brew --prefix)"/lib || exit 1
for l in "$(brew --prefix)"/Cellar/*/*/lib/*.dylib; do
  cp -a $l ${WORKSPACE_DIR}/$artifact_name/lib
  f=${WORKSPACE_DIR}/$artifact_name/lib/$(basename $l)
  if [ ! -L $f ]; then
    # Problem: libraries installed by brew have load commands in them that use absolute paths.
    # This renders them unusable in any other location other than the one they were installed in.
    # Solution:

    # update the LC_ID_DYLIB command of current library so that it's name is a relative path,
    # not absolute (as brew sets it), so that it can be located during linking
    install_name_tool -id "@rpath/$(basename $f)" $f
    # update the LC_LOAD_DYLIB commands that refer to dependencies of current library that have been
    # installed by brew and set as local paths so that their names are also relative paths and the dependencies can be located during linking
    otool -L $f | tail -n +3 | awk -F" " '{print $1}' | (grep -E "^($(brew --prefix)|@loader_path)" || [ "$?" == "1" ]) | while read -r line; do install_name_tool -change $line "@rpath/$(basename $line)" $f; done
    # if compiled on arm architecture then the libraries will be codesigned on `brew install`
    # and need to be resigned, because the previous changes invalidated the signature
    [[ $ARCHITECTURE == arm ]] && codesign --sign - --force --preserve-metadata=entitlements,requirements,flags,runtime $f
  fi
done
