#!/bin/bash

set -ev

echo "[MVN-SSF] Using Branch ${TRAVIS_BRANCH}"

if [ "${TRAVIS_BRANCH}" = "master" ]; then
	MVN_PROFILES="sonar,versioneye"
else
  MVN_PROFILES="sonar"
fi

echo "[MVN-SSF] Invoking mvn using profiles $MVN_PROFILES"

mvn clean package -P$MVN_PROFILES; else mvn clean package -Psonar
