#!/bin/sh

rm -rf output-zboxdesktop-*

packer build \
    --var-file="zboxdesktop-builder.json" \
    --var-file="zboxdesktop-13.2.json" \
    zboxdesktop.json
