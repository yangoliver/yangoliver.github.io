#!/bin/bash

echo "publish to github page"
git push -u origin

echo "#################################################"
git remote -v | grep gitcafe
if [ $? -ne 0 ]; then
	echo "can't find gitcafe as a remote branch, adding gitcafe now..."
	git remote add coding https://git.coding.net/yangoliver/yangoliver.git
fi

echo "publish to gitcafe page"
git push -u coding master:gitcafe-pages
