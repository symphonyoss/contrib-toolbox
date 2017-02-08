#
# Copyright 2016 The Symphony Software Foundation
#
# Licensed to The Symphony Software Foundation (SSF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
#
#!/bin/bash

# oc-deploy.sh
#
# This scripts installs Openshift CLI (oc), logs into https://api.preview.openshift.com
# and starts an image build, passing the binaries from file.
# More info on https://docs.openshift.org/latest/dev_guide/builds.html#binary-source

# Environment variables needed:
# - OC_TOKEN - The Openshift Online token
# - OC_BINARY_FOLDER - contains the local path to the binary folder to upload to the container as source
# - OC_BUILD_CONFIG_NAME - the name of the BuildConfig registered in Openshift

# Define oc package coordinates
OC_VERSION=v1.4.1
OC_RELEASE=$OC_VERSION-3f9807a-linux-64bit
OC_FOLDER_NAME=openshift-origin-client-tools-$OC_RELEASE
OC_URL="https://github.com/openshift/origin/releases/download/$OC_VERSION/$OC_FOLDER_NAME.tar.gz"

# Download and unpack oc
curl -L $OC_URL | tar xvz

if [[ -n "$OC_DEBUG" ]]; then
  echo "showing $OC_FOLDER_NAME folder content..."
  ls -l $OC_FOLDER_NAME
fi
# Log into Openshift Online and use project botfarm
./$OC_FOLDER_NAME/oc login https://api.preview.openshift.com --token=$OC_TOKEN ; oc project botfarm
echo "Logged into api.preview.openshift.com"

# Start the build
./$OC_FOLDER_NAME/oc start-build $OC_BUILD_CONFIG_NAME --from-dir=$OC_BINARY_FOLDER --wait=true
echo "Build of $OC_BUILD_CONFIG_NAME completed"
