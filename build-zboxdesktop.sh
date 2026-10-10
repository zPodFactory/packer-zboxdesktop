#!/bin/sh

# The appliance release version: names the OVA and is what the OVF reports. It tracks the
# Debian point release of the var file below, plus a third digit for a respin of the same
# Debian version. `tools/release.py X.Y[.Z]` writes both lines.
APPLIANCE_VERSION="13.7"

rm -rf output-zboxdesktop-*

packer build \
  --var-file="zboxdesktop-builder.json" \
  --var-file="zboxdesktop-13.7.json" \
  --var appliance_version="$APPLIANCE_VERSION" \
  zboxdesktop.json
