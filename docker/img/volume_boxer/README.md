## Docker Archiver Container

### Initial Launch



### Starting

From then on, you'll 

```
docker start -ai my_data_archive shell
```

### Mirroring

When `/data` is already a git repository associated with the archive (as
typical on subsequent runs), the archiver

* fetches the remote repo into the target git index. This makes no changes to
  the contents of the target; you can decide when and whether to do a merge or
  rebase or whatever.

* mirrors the git index of the target into the archive. If you add or prune
  branches in the target, they will be added or pruned in the archive.

### First-time actions when the target has content

If the target has content, but isn't a git repo, we:

* make it a git repo;
* give it a remote named 'stored' pointing to the archive;
* set the git HEAD to match the master branch of stored

This doesn't change the contents of the target, but makes it easy for you to get
the mirror in sync.

### Shell access to the data container

To get a busybox console on the data container, supply `shell` as a
command. For example:

```
docker start -ai my_data_archive shell
```

### Sending git commands

Any other args are passed to git:

```
docker start -ai my_data_archive log -p master
```

### Merging

The contents of the archive are now present in the target's git repo. If there
are changes and you wish to update the target, you can for example run

    git merge stored/master

EOF

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

will make the archive's contents match the contents of all branches in /data.

#### tl;dr, how do I just nuke the contents of the target from orbit?

It's the only way to be sure. Assuming you want to track the master branch of
the archive, run

cd /data
git reset stored/master
git stash  save --all && git stash drop
