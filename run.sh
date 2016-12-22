#!/bin/bash
set -eu


# setup variables
  # must be absloute path
  BACKUP_DIR=""
  BACKUP_FILE_NAME=""
  BACKUP_S3_BUCKET=""
  IGNORED_DBS=""
  LOCK_FILE=""

  # prepare tmp dir, inside backup dir
    BUFFER_DIR="$(mktemp -d  --tmpdir=$BACKUP_DIR/)"


# Setup traps and locks
  # script lock
  echo checking lock
  if [ -a $LOCK_FILE ]; then
    echo "lock file exists cant run."
    exit 0
  else
    echo no lock file, creating one
    touch $LOCK_FILE
  fi

  # traps
    # success/interruption
    trap "echo Cleaning up $BUFFER_DIR ;rm -rf $BUFFER_DIR; rm -f $LOCK_FILE;exit"  EXIT SIGHUP SIGINT
    # failure
    trap 'script terminated; rm -f $LOCK_FILE;echo backup_failed | mail -s "mongo full backup"  root;'     SIGTERM

# dump DB
  # run mongodump, dump this into the tmp dir inside backup dir
  mongodump -o $BUFFER_DIR --quiet

  # remove unwanted DBs from tmp dir
  for DB in $IGNORED_DBS
    do
      echo rm -rf $BUFFER_DIR/$DB
  done

  # get all Database directories
  echo creating backup file
  cd $BUFFER_DIR
  # compress
  tar czf $BACKUP_DIR/$BACKUP_FILE_NAME *

# upload  backup
  # upload to S3
  echo /usr/local/bin/aws s3 cp $BACKUP_DIR/$BACKUP_FILE_NAME   s3://$BACKUP_S3_BUCKET --profile=default
  echo "Done, full  backup done successfully"
