#!/bin/sh

set -e ; set +v

cmd=${1-mirror}
shift;

echo "Command: $cmd"
echo "Args: $@"

usage="Please supply either 'help', 'mirror [/directory/to/mirror]', or 'shell'. With no args, 'mirror /data' is assumed."

case "$cmd" in
  help*|\-\-help*)
    cat /archiver/README-archiver.md
    ;;
  shell|/bin/sh)
    exec /bin/sh "$@"
    ;;
  mirror)
    TARGET=${1-/data}
    shift
    echo "mirroring '$TARGET'"
    if [ -n "$*" ] ; then echo "Too many args: '$cmd' '$TARGET' '$@'." ; echo "$usage" ; exit 20 ; fi
    true # we'll pick up after the case statement
    ;;
  *)
    echo "unknown command: '$cmd $@'" ; echo
    echo "$usage"
    exit 1
    ;;
esac

if [   -z "$ARCHIVE"  ] ; then echo "The ARCHIVE env var must be set" ; exit 21 ; fi
if [   -z "$TARGET"   ] ; then echo "The TARGET  env var must be set" ; exit 22 ; fi
if [ \! -d "$TARGET"  ] ; then echo "The TARGET '$TARGET' must exist as a directory" ; exit 23 ; fi

echo
cd "$TARGET"

if   [ -z "`ls -1A $TARGET/`" ] ; then

  echo "  ===== Target is empty: filling it"
  echo
  cd "$TARGET"
  git clone -o stored "$ARCHIVE" .
  git remote set-head stored --delete || true
  echo
  cat /archiver/README-new_repo.md

elif [ -e "$TARGET"/.git ] ; then

  echo "  ===== Target is a git repo, "
  echo
  if git remote | grep -q 'stored' ; then
    echo "with correct remote"
    echo
  else
    echo "without a remote named 'stored', so making one and pointing it to the archive"
    echo
    git remote add stored "$ARCHIVE" || true
    git remote set-head stored --delete || true
  fi
  echo
  echo "  ===== Fetching from the archive into $TARGET, but not updating any contents of $TARGET."
  echo
  git fetch stored || true
  echo
  cat /archiver/README-merging.md
  echo
  echo "  ===== For other options, start the container with the 'help' argument"
  echo "  ===== (or see the README-archiver.md if it's still in the target directory)"

else

  echo "  ===== Target has data, but is not a git repo."
  echo
  echo "  ===== Making it a git repo"
  echo
  git init
  git remote add --fetch stored "$ARCHIVE"
  git remote set-head stored --delete || true
  echo
  echo "  ===== Advancing to the last commit in stored/master"; echo
  git reset stored/master || true
  echo
  echo "  ===== The target is now a git repo, but no changes have been made to its contents."
  echo "  ===== You will probably want to incorporate them."
  echo
  cat /archiver/README-resetting.md

fi
echo

cd $TARGET
git gc

echo "  ===== Updating archive to mirror $TARGET"; echo

cd $ARCHIVE
git config pack.packSizeLimit 20m
git config pack.windowMemory 256m
git fetch -p $TARGET/.git || true

echo "  ===== And updating $TARGET to know that archive has received"; echo

cd $TARGET
git config pack.packSizeLimit 20m
git config pack.windowMemory 256m
git fetch stored || true

echo "Branches and recent activity:"

git branch -a
git log --oneline | head

echo "Mirror complete"
cat <<'EOF'

  You may now
* see this container with `docker ps -a`
* review changes with `docker diff`
* commit them with `docker commit`

Docker diff may show some gratuitous changes in files such as FETCH_HEAD even
when no changes have been mirrored -- content changes show up in objects and
pack directories.

EOF
