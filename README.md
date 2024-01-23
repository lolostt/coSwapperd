
# coSwapperd
This script will:
 - Check and disable if default swap exists in /var/swap.
 - Create SWAP_FILENAME file in mounted STORAGE_NAME volume for enable new swap location. Its size will be SWAP_SIZE.

### Motivation
This script was created to try to prevent the aging of the flash memory on a Raspberry Pi. Using virtual memory in an SD card's flash memory can lead to excesive wear and premature aging. Use swap memory from a mechanical disk drive may be usefull.

## Getting Started
### Prerequisites
#### Software
1. Raspberry Pi OS. **Only tested on Debian 11 (bullseye)**. Other OS may work.
2. Superuser privileges.

### Installing
1. Place script somewhere. 
Give execution permission with ```chmod +x coSwapperd.sh```
3. Run ```coSwapperd.sh -e``` to enable start at boot.

## Usage
Just execure like a regular script. **Options are required**.
 ```coSwapperd.sh -s```

### Available options
```-i | --initcheck``` Initial check. Mount point reachable check.
```-e | --enable``` Enable at boot using crontab.
```-s | --start``` Disable default swap and create new one.

### Script behaviour
You can set some variables to customize script behaviour:
 - STORAGE_NAME **[Mandatory edit]**. Mounted volume name where swap file will be located.
 - SWAP_SIZE. Sets swap file size in megabytes.
 - SWAP_FILENAME. Sets swap file name.
 - BOOT_WAIT_TIME. Sets time in seconds scripts waits for system to start.
 - DISKOPS_WAIT_TIME. Sets time in seconds scripts waits for disk operations to finish. Prevents errors related to slow mechanical hard drives.

## Authors
* **lolost** - [sleepingcoconut.com](https://sleepingcoconut.com/)

## License
This project is licensed under the [Zero Clause BSD license](https://opensource.org/licenses/0BSD).