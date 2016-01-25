#!/bin/bash

echo "publish to github page"
git push -u origin

echo "#################################################"
#
# git remote add gitcafe https://gitcafe.com/yangoliver/yangoliver.git
#
echo "publish to gitcafe page"
git push -u gitcafe master:gitcafe-pages
