#!/bin/bash

# Licensed to the Symphony Software Foundation (SSF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The SSF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Name: validate-license-source.sh
# Author: maoo@symphony.foundation
# Creation date: 25 May 2016
# Description: Validates source code against Symphony Software Foundation (SSF) acceptance criteria returning a list of issues - https://symphonyoss.atlassian.net/wiki/x/SAAx ; source code can be specified as file-system path or URL pointing to a ZIP file
# Tested on:
# 1. OSX Terminal (SHELL=/bin/zsh)
# 2. Windows Bash, installed following http://www.howtogeek.com/249966/how-to-install-and-use-the-linux-bash-shell-on-windows-10/
#
TMP_FOLDER_PARENT=/tmp
TMP_FOLDER=$TMP_FOLDER_PARENT/validate-license-source
LICENSED_TO_SSF_MATCH="Licensed to The Symphony Software Foundation (SSF)"
ASF_LICENSE_MATCH="to you under the Apache License, Version 2.0"
NOTICE_MATCH=("http://symphony.foundation" "Copyright 2016 The Symphony Software Foundation")
LICENSE_MATCH=("http://www.apache.org/licenses/" "Version 2.0, January 2004" "Copyright 2016 The Symphony Software Foundation")
NOT_INCLUDED_LICENSES="Binary Code License (BCL)\|GNU GPL 1\|GNU GPL 2\|GNU GPL 3\|GNU LGPL 2\|GNU LGPL 2.1\|GNU LGPL 3\|Affero GPL 3\|NPL 1.0\|NPL 1.1\|QPL\|Sleepycat License\|Microsoft Limited Public License\|Code Project Open License\|CPOL"
ITEM_TO_SCAN=$1

# Cleaning and creating $TMP_FOLDER
rm -rf $TMP_FOLDER; mkdir -p $TMP_FOLDER

# Parse the (mandatory) folder to scan as first param
if [[ $# -eq 0 ]] ; then
  echo 'validate-license-source.sh'
  echo 'Validates source code against Symphony Software Foundation (SSF) acceptance criteria - https://symphonyoss.atlassian.net/wiki/x/SAAx'
  echo 'Source code can be specified as file-system path or URL pointing to a ZIP file'
  echo ''
  echo 'Usage: ./validate-license-source <folder_to_scan_path|URL_to_zip_file>'
  echo 'Example: curl -sL https://raw.githubusercontent.com/symphonyoss/contrib-toolbox/master/validate-license-source.sh | bash -s -- https://symphonyoss.atlassian.net/secure/attachment/10400/VirtualDesk_Xmpp.zip > report.txt'
  exit 0
fi

if [ -d $ITEM_TO_SCAN ]; then
  FOLDER_TO_SCAN=$1
elif [[ "$ITEM_TO_SCAN" == http* ]]; then
  ITEM_FILE_NAME=`basename $ITEM_TO_SCAN`
  curl -sL $ITEM_TO_SCAN > $TMP_FOLDER/$ITEM_FILE_NAME
  if [[ "$ITEM_TO_SCAN" == *zip ]]; then
    FOLDER_TO_SCAN=$TMP_FOLDER/folder-to-scan
    unzip $TMP_FOLDER/$ITEM_FILE_NAME -d $FOLDER_TO_SCAN > /dev/null
  fi
fi

if [ ! -f "$FOLDER_TO_SCAN/LICENSE" ]; then
  echo "CRIT-1 - Missing LICENSE file"
else
  for match in "${LICENSE_MATCH[@]}"; do
    grep -L "$match" $FOLDER_TO_SCAN/LICENSE > /dev/null
    if [ $? == 1 ]; then
      echo "CRIT-1 - LICENSE file not matching '$match'"
    fi
  done
fi

if [ ! -f "$FOLDER_TO_SCAN/NOTICE" ]; then
  echo "CRIT-2 - Missing NOTICE file"
else
  for match in "${NOTICE_MATCH[@]}"; do
    grep -L "$match" $FOLDER_TO_SCAN/NOTICE > /dev/null
    if [ $? == 1 ]; then
      echo "CRIT-2 - NOTICE file not matching '$match'"
    fi
  done
fi

echo "CRIT-3 - List of files not licensed to The Symphony Software Foundation (SSF) ..."
echo "==========================="
find $FOLDER_TO_SCAN -type f ! -name 'LICENSE' ! -name 'NOTICE' ! -name '*.jar' ! -name '.classpath' ! -name '.project' | xargs -I {} grep -L "$LICENSED_TO_SSF_MATCH" {}
echo "==========================="
echo "CRIT-3 - List of files missing Apache license header"
echo "==========================="
find $FOLDER_TO_SCAN -type f ! -name 'LICENSE' ! -name 'NOTICE' ! -name '*.jar' ! -name '.classpath' ! -name '.project' | xargs -I {} grep -L "$ASF_LICENSE_MATCH" {}
echo "==========================="

# Find licenses on source files that are incompatible with ASF 2.0
RESULTS=`find $FOLDER_TO_SCAN -type f ! -name 'LICENSE' ! -name 'NOTICE' ! -name '*.jar' ! -name '.classpath' ! -name '.project' | xargs -I {} grep -R "$NOT_INCLUDED_LICENSES" {}`
if [ -n "$RESULTS" ]; then
  echo "CRIT-4 - Check source code for incompatible licenses"
  echo "==========================="
  echo $RESULTS
  echo "==========================="
fi

# Find licenses on JAR files that are incompatible with ASF 2.0
TMP_EXPLODED_JAR=$TMP_FOLDER/jars
mkdir -p $TMP_EXPLODED_JAR
for jarpath in $(find $FOLDER_TO_SCAN -type f -name \*.jar); do
  jarname=`basename $jarpath`
  mkdir -p $TMP_EXPLODED_JAR/$jarname
  unzip $jarpath -d $TMP_EXPLODED_JAR/$jarname > /dev/null

  # Find licenses on source files that are incompatible with ASF 2.0
  RESULTS=`find $TMP_EXPLODED_JAR/$jarname -type f ! -name '*.jar' ! -name '.classpath' ! -name '.project' | xargs -I {} grep -R "$NOT_INCLUDED_LICENSES" {}`
  if [ -n "$RESULTS" ]; then
    echo "CRIT-4 - Check JAR $jarname for incompatible licenses"
    echo "==========================="
    echo $RESULTS
    echo "==========================="
  fi
done

#Deleting $TMP_FOLDER
rm -rf $TMP_FOLDER
echo ""
echo "To fix the reported issues, read more on https://symphonyoss.atlassian.net/wiki/x/SAAx"
