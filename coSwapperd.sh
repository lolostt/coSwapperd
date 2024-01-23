#!/bin/bash
#build 1
set -o nounset

# This script will create SWAP_FILENAME file in STORAGE_NAME volume to enable swap memory.
# If system default swap is detected, it will be disabled.
#
# Requirements:
# - Superuser privileges.

# Copyright (C) 2024 Sleeping Coconut https://sleepingcoconut.com

#----VARIABLES--------------------------------------------------------------------------------------
STORAGE_NAME="MANDATORY_EDIT"
SWAP_SIZE="1024" # megabytes

SWAP_FILENAME="swap.swp"
BOOT_WAIT_TIME=120 # seconds
DISKOPS_WAIT_TIME=5 # seconds

#----RUNTIME VARIABLES------------------------------------------------------------------------------
STORAGE_MOUNT_POINT="/mnt/"$STORAGE_NAME""
DESIRED_SWAP_PATH=""$STORAGE_MOUNT_POINT"/"$SWAP_FILENAME""

# Zero Clause BSD license {{{
#
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without
# fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
# SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
# NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
# OF THIS SOFTWARE.
# }}}

#----FUNCTIONS--------------------------------------------------------------------------------------
function log () { logger -t "coSwapperd" $*; echo "--> $*"; }
function logError () { logger -t "coSwapperd" -s $*; }

function usage() {
  echo "usage: `basename $0` [-s | -e | -i]"
}

function initCheck() {
  #Check 1: root privileges
  if ! [ $(id -u) = 0 ]; then
    logError "this script needs to be run as root."
    exit 1
  fi
  #Check 2: reach mount point
  if [ ! -d "$STORAGE_MOUNT_POINT" ]; then
    logError "error during initial check. Could not reach storage mount point..."
    return 1
  fi
}

function enableAtBoot() {
  SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
  SCRIPT_NAME=`basename $0`
  CRONTAB_ENTRY="@reboot "$SCRIPT_DIR"/"$SCRIPT_NAME" -s >/dev/null 2>&1"
  export CRONTAB_NOHEADER=N # Required by Debian

  if ! crontab -l | grep -q "$CRONTAB_ENTRY"; then
    (crontab -l; echo "$CRONTAB_ENTRY") | crontab -
  fi
}

function removeDefaultSwap() {
  /usr/sbin/swapoff /var/swap
  sleep $DISKOPS_WAIT_TIME
}

function createSwap() {
  rm $STORAGE_MOUNT_POINT/$SWAP_FILENAME >/dev/null 2>&1
  sleep $DISKOPS_WAIT_TIME
  dd if=/dev/zero of=$STORAGE_MOUNT_POINT/$SWAP_FILENAME bs=1M count=$SWAP_SIZE
  sleep $DISKOPS_WAIT_TIME
  chmod 600 $STORAGE_MOUNT_POINT/$SWAP_FILENAME
  chown root:root $STORAGE_MOUNT_POINT/$SWAP_FILENAME
  /usr/sbin/mkswap $STORAGE_MOUNT_POINT/$SWAP_FILENAME 2>&1
  sleep $DISKOPS_WAIT_TIME
  /usr/sbin/swapon $STORAGE_MOUNT_POINT/$SWAP_FILENAME 2>&1
}

# Possible returns:
# - 0: No swap
# - 1: Default swap
# - 2: Desired swap
# - 3: Unknown swap
# - 4: Default + desired swap
# - 5: Default + unknown swap
# - 6: Desired + unknown swap
# - 7: Unknown swap
function swapCheck() {
  iterations=`cat /proc/swaps | awk '{ print $1 }' | grep -c '.'`

  if [ "$iterations" -eq "2" ]; then
    currentSwapPath=`cat /proc/swaps | sed -sn 2p | awk '{ print $1 }'`
    if [ "$currentSwapPath" = "/var/swap" ]; then
      echo 1
      return 1
    elif [ "$currentSwapPath" = "$DESIRED_SWAP_PATH" ]; then
      echo 2
      return 2
    else
      echo 3
      return 3
    fi
  elif [ "$iterations" -gt "2" ]; then
    defaultFlag=0
    desiredFlag=0
    for index in $(seq 2 $iterations);
    do
      currentIterationSwapPath=`cat /proc/swaps | sed -sn "$index"p | awk '{ print $1 }'`
      if [ "$currentIterationSwapPath" = "/var/swap" ]; then
        defaultFlag=1
      elif [ "$currentIterationSwapPath" = "$DESIRED_SWAP_PATH" ]; then
        desiredFlag=1
      fi
    done
    if [ "$defaultFlag" -eq "1" ] && [ "$desiredFlag" -eq "1" ]; then
      echo 4
      return 4
    elif [ "$defaultFlag" -eq "1" ] && [ "$desiredFlag" -eq "0" ]; then
      echo 5
      return 5
    elif [ "$defaultFlag" -eq "0" ] && [ "$desiredFlag" -eq "1" ]; then
      echo 6
      return 6
    else
      echo 7
      return 7
    fi
  else
    return 0
  fi
}

function startSwap() {
  initCheck || { log "init check failed"; exit 1; }
  sleep $BOOT_WAIT_TIME

  case $(swapCheck) in
  0 | 3 | 7)
    log "creating new swap location."
    createSwap || { log "swap location creation failed"; return 1; }
    ;;
  1 | 5)
    log "default swap found. Removing."
    removeDefaultSwap || { log "remove default swap failed"; return 1; }
    log "creating new swap location."
    createSwap || { log "swap location creation failed"; return 1; }
    ;;
  4)
    log "default swap found. Removing."
    removeDefaultSwap || { log "remove default swap failed"; return 1; }
    ;;
  2 | 6)
    log "no default swap. Swap in desired location. Nothing to do."
    ;;
  *)
    log "invalid swap status code."
    return 1
    ;;
  esac
}

#----SCRIPT-----------------------------------------------------------------------------------------
if [ $# -lt 1 ]; then
  usage
else
  while [ "$1" != "" ]; do
    case $1 in
      -e | --enable )     log "enabling at boot"
                          enableAtBoot || { logError "enable at boot failed"; exit 1; }
                          exit 0
                          ;;
      -i | --initcheck )  log "init check"
                          initCheck || { logError "init check failed"; exit 1; }
                          exit 0
                          ;;
      -s | --start )      log "starting swap"
                          startSwap || { logError "swap start failed"; exit 1; }
                          exit 0
                          ;;
      * )                 usage
                          exit 1
    esac
    shift
  done
fi