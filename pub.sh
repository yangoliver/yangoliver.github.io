#!/bin/bash

echo "publish to github page\n"
git push -u origin

echo "#################################################\n"
#
# git remote add gitcafe https://gitcafe.com/yangoliver/yangoliver.git
#
echo "publish to gitcafe page\n"
git push -u gitcafe master:gitcafe-pages
