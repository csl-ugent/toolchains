#!/bin/bash

fpath=$1

fname_and_fext=`basename $fpath`
fname="${fname_and_fext%%.*}"
fext="${fname_and_fext#*.}"

git stash 2>&1 >/dev/null

# save the current git revision to a file, as the archive
# will not contain a .git-directory anymore
git rev-parse --short=10 HEAD > .git-revision

# make a temporary commit
git add .git-revision
git commit -m "temp" 2>&1 >/dev/null

# create the archive, only containing the files contained
# in the git repository
git archive --format=$fext --prefix=$fname/ HEAD > $fpath

# undo the temporary commit
git reset --hard HEAD~1 2>&1 >/dev/null

git stash pop 2>&1 >/dev/null
