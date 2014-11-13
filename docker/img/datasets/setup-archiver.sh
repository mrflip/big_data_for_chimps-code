#!/bin/sh
set -e; set -v

#
# Preliminaries
#

# Make a fake git identity we can use for commits
#
git config --global user.email "nobody@bigdataforchimps.com"
git config --global user.name "bd4c/datasets_archive docker archive robot"

# Fix a bug in the busybox .bashrc (it doesn't have bash)
#
sed -i 's/if.*shopt.*then/if false; then/' ~/.bashrc

cat > /archiver/README-new_repo.md <<'EOF'
### First-time actions

If the target has content, but isn't a git repo, we:

* make it a git repo;
* give it a remote named 'stored' pointing to the archive;
* set the git HEAD to match the master branch of stored

This doesn't change the contents of the target, but makes it easy for you to get
the mirror in sync.
EOF

cat > /archiver/README-merging.md <<'EOF'
### Merging

The contents of the archive are now present in the target's git repo. If there
are changes and you wish to update the target, you can for example run

    git merge stored/master

EOF

cat > /archiver/README-resetting.md <<'EOF'

### Resetting the target to match the archive

If what you want is to mostly or fully discard what's in the target and reset to
what's in the archive, first move git's head to the repo you want to be at, for
example stored/master:

    git reset stored/master

You still haven't changed data; you've only told git where you want history to
pick up from. Now add and commit anything you wish to keep, and stash the rest
with

    git stash save --all -m "I think I don't want this stuff"

All unstaged, untracked and ignored files will now have been moved out of the
way -- you should now see all and only the items in the branch you wanted:

    git diff HEAD

should be clean. To drop the stashed data,

    git stash list
    git stash drop [sha of the stash to remove]

Restarting the dataset_archiver container by e.g.

    docker start -ia my_archive mirror

will make the archive's contents match the contents of all branches in $TARGET.

#### tl;dr, how do I just nuke the contents of the target from orbit?

It's the only way to be sure. Assuming you want to track the master branch of
the archive, run

cd $TARGET
git reset stored/master
git stash  save --all && git stash drop

EOF

#
# Construct an empty git repo. We will imprint on the first one we see anyway.
#

TARGET=${TARGET-/data}
mkdir -p /data

# Create the git repo, make a trivial initial commit
#
cd $TARGET
git init
cp /archiver/README.md ./README-archiver.md
git add -A .
git commit -m "Initial commit"

# Create a mirror repo
#
git clone --mirror $TARGET/.git $ARCHIVE

# Now fake a first-time mirror
rm -rf $TARGET/.??* $TARGET/*

/bin/archiver.sh mirror $TARGET

cat /archiver/archive.git/FETCH_HEAD
