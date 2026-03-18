#!/bin/sh

rm -rf output-zboxdesktop-*

packer build \
    --var-file="zboxdesktop-builder.json" \
    --var-file="zboxdesktop-13.4.json" \
    zboxdesktop.json
