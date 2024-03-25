#!/bin/bash

mkdir -p dist
cd dist
list_asset_url="https://api.github.com/repos/isuruf/openmm-wheels/releases/tags/${1}"
curl -s $list_asset_url | grep "\"browser_download_url\"" | xargs -i echo {} | cut -b 23- | xargs -i curl -LO {}
