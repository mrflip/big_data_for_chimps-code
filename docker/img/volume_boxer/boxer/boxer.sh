#!/bin/bash

set -e ; set +v

cmd=${1-help}
shift;

echo "Command: '$cmd' ; Args: $@"
echo

usage="Please supply either 'help', 'archive /mounted/volume', 'force-update /mounted/volume', 'pushpull /mounted/volume', or 'shell'."

case "$cmd" in
  help*|\-\-help*)
    cat /boxer/README.md
    echo
    echo $usage
    echo
    echo "BAILING OUT TO A SHELL" ; exec /bin/bash
    ;;
  shell|/bin/sh|/bin/bash)
    echo
    echo "Running shell with args '$@'. When you've done what you need to do, commit the volume then re-run with archive, force-update, or pushpull. The boxer script and README.md are in /boxer, and the mirror of your data is in /boxer/archive"
    echo
    exec /bin/bash "$@"
    ;;
  pushpull)
    TARGET="$1"
    echo "pushpulling '$TARGET'"
    #
    if   [ -z "$TARGET" ] ; then
      echo "oops TARGET not given"
    elif [ -z "`ls -1A $TARGET/`" ] ; then
      echo "  ===== Target shared volume is empty: filling it"
      cmd=force-update
    else
      echo "  ===== Target has contents: updating archive to match contents of target shared volume."
      cmd=archive
    fi
    #
    # ... we'll pick up after the case statement
    #
    ;;
  force-update)
    true # continue belos
    ;;
  archive)
    true # Continue below
    ;;
  *)
    echo "unknown command: '$cmd $@'" ; echo
    echo "$usage"
    echo "BAILING OUT TO A SHELL" ; exec /bin/bash
    ;;
esac
echo

TARGET="$1"
shift
if [ "$1" = "--dry-run" ] ; then echo "DOING DRY RUN" ; DRYRUN="--dry-run" ; shift ; fi

if [ -z "$TARGET" ] ; then echo "No volume to mirror specified." ; echo "$usage"        ; echo "BAILING OUT TO A SHELL" ; exec /bin/bash ; fi
if [ -n "$*"      ] ; then echo "Too many args: '$cmd' '$TARGET' '$@'." ; echo "$usage" ; echo "BAILING OUT TO A SHELL" ; exec /bin/bash ; fi

if test -d $TARGET/ && mount | grep -v -e ' on /(dev|proc)' | grep -q  "$TARGET" ; then
  echo "$TARGET is a directory and looks like a mounted file system, good to go"
else
  cat /boxer/README.md
  echo
  echo "  ===== The specified target, '$TARGET', is not a mounted filesystem."
  echo "  ===== Here are the mounted filesystems: "
  mount
  echo
  df
  echo
  echo "  ===== If you don't see your choice ('$TARGET') among those, stop, rm and re-run this volume using the --volume or --volumes-from flag as appropriate"
  echo
  exec /bin/bash
fi

if   [ "$cmd" = "archive" ] ; then
  action="Updating archive to match contents of target shared volume"
  echo "  ===== $action"
  rsync --verbose --itemize-changes --inplace --archive \
    --links --hard-links --omit-dir-times --copy-unsafe-links \
    --delete-during \
    $DRYRUN \
    $TARGET/ /boxer/archive/
elif [ "$cmd" = "force-update" ] ; then
  action="Clobbering existing files to match contents of archive"
  echo "  ===== $action"
  rsync --verbose --itemize-changes --inplace --archive \
    --links --hard-links --omit-dir-times --copy-unsafe-links \
    --delete-during \
    $DRYRUN \
    /boxer/archive/ $TARGET/ 
else
  echo "should not have gotten here: command '$cmd'"
  echo "BAILING OUT TO A SHELL" ; exec /bin/bash
fi

echo "If any files were updated, you'd see them above the 'sent X bytes' line. Here's what's in the top-level of the target and archive:"
echo "Target:"
ls -l "$TARGET"
echo 
echo "Archive:"
ls -l /boxer/archive
echo

echo
echo "Done with $action"
echo
if [ -n "$DRYRUN" ] ; then
  echo "JUST KIDDING NOTHING HAPPENED THIS WAS ALL A DREAM"
  echo "you launched with --dry-run -- stop and remove this container, then re-run without the flag to actually do anything"
else
  echo "Mirror complete"
fi

cat <<'EOF'

If you ran this daemonized, doing `docker attach (container_name)` will put you back in the shell

If you ran this interactively, you are now in a shell on the data container. Once youu quit, you may:

* rerun the script and get an interactive shell with `docker start -ia`
* see this container's status with `docker ps -a`
* review changes with `docker diff`
* commit them with `docker commit (container_name) (image_name:tag)`

EOF

exec /bin/bash
