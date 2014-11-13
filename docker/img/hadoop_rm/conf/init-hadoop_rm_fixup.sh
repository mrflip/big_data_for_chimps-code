#!/bin/bash
set -e ; set -x

#
# If you choose to mount a container underneath these, the permissions will be wrong.
# So we have to fix that at boot time.
#
# We are purposefully *not* making the directories. These commands will fail if
# they are missing, and so the container will fail if they are missing, and that
# is because something has gone terribly wrong if they are missing. They're
# built into the image at birth, or you are welcome to overlay a volume of your
# own.
#
ls -l $HADOOP_BULK_DIR
chown mapred:mapred $HADOOP_BULK_DIR/jobstatus
