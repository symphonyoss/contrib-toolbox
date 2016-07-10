#!/bin/bash

set -e

if [ -z "$SCM_BRANCH" ]
then
  SCM_BRANCH=${TRAVIS_BRANCH}
fi  

if [ -z "$MVN_COMMAND" ]
then
  MVN_COMMAND="mvn clean package"
fi  

if [ -z "$MVN_MASTER_PROFILES" ]
then
  MVN_MASTER_PROFILES="versioneye"
fi  

if [ -z "$MVN_ALLBRANCHES_PROFILES" ]
then
  MVN_ALLBRANCHES_PROFILES=""
fi  

echo "[MVN-SSF] Using Branch $SCM_BRANCH"

if [ "$SCM_BRANCH" = "master" ]; then
  MVN_PROFILES=$MVN_MASTER_PROFILES
else
  MVN_PROFILES=$MVN_ALLBRANCHES_PROFILES
fi

echo "[MVN-SSF] Invoking mvn using profiles $MVN_PROFILES"

$MVN_COMMAND -P$MVN_PROFILES
