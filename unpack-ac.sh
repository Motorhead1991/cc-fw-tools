#!/bin/bash

project_root="$PWD"

# Source the utils.sh file
source "$project_root/TOOLS/helpers/utils.sh" "$project_root"

# check the number of arguments
if (($# != 1)); then
  echo "Usage: ./unpack.sh update_file"
  echo "Example: ./unpack.sh FW/AC104_K2Pro_1.1.0_3.0.5_update.bin"
  exit 1
fi

UPDATE_FILE="$1"
UPDATE_FILENAME=$(basename -- "$UPDATE_FILE")
UPDATE_FILE_EXT="${UPDATE_FILENAME##*.}"

# check the input file
if [ ! -f "$UPDATE_FILE" ]; then
  echo -e "${RED}ERROR: Cannot find the input file ${UPDATE_FILE}${NC}"
  exit 1
fi

# check the input file ext
if [ "$UPDATE_FILE_EXT" != "bin" ] && [ "$UPDATE_FILE_EXT" != "swu" ] && [ "$UPDATE_FILE_EXT" != "zip" ]; then
  echo -e "${RED}ERROR: Unknown file extension '${UPDATE_FILE_EXT}'${NC}"
  exit 2
fi

# check the required tools
check_tools "cpio unsquashfs unzip ack2_swu_decrypt.py python3"

# set the custom decrypt tool
DECRYPT_TOOL=$(which "ack2_swu_decrypt.py")
if [ -z "$DECRYPT_TOOL" ]; then
  # if not installed use the local copy
  DECRYPT_TOOL="TOOLS/ack2_swu_decrypt.py"
fi

# remove old temp files if present
rm -rf unpacked
mkdir unpacked

# preprocessing the update file
if [ "$UPDATE_FILE_EXT" == "bin" ]; then
  # decrypt the update if it is encrypted
  $DECRYPT_TOOL -i "$UPDATE_FILE" -o ./unpacked/update.zip
  if [ ! -f "./unpacked/update.zip" ]; then
    echo -e "${RED}ERROR: Cannot find the input file './unpacked/update.zip' ${NC}"
    exit 4
  fi
  cd unpacked || exit 5
  unzip update.zip
  rm -r update.zip
  cd ..
else
  if [ "$UPDATE_FILE_EXT" == "zip" ]; then
    # zip file
    cp "$UPDATE_FILE" ./unpacked/update.zip
    cd unpacked || exit 5
    unzip update.zip
    rm -r update.zip
    cd ..
  else
    # swu file, prepare a copy of the file
    mkdir ./unpacked/update
    cp "$UPDATE_FILE" ./unpacked/update/update.swu
  fi
fi

# check the input file
if [ ! -f "./unpacked/update/update.swu" ]; then
  echo -e "${RED}ERROR: Cannot find the input file './unpacked/update/update.swu' ${NC}"
  exit 6
fi

# extract the update
cd unpacked || exit 7
cpio -idv <./update/update.swu

# verify that all needed parts exist
FILES="sw-description sw-description.sig boot-resource uboot boot0 kernel rootfs dsp0 cpio_item_md5"
for i in $FILES; do
  if [ ! -f "$i" ]; then
    echo -e "${RED}ERROR: Cannot find the expected update component '$i' ${NC}"
    cd ..
    exit 8
  fi
done

# unpack the rootfs
unsquashfs rootfs

cd ..

echo ""
echo -e "${GREEN}Unpacking DONE! Check the 'unpacked' folder for the result.${NC}"
echo ""

exit 0
