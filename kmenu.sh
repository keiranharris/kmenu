#!/bin/sh

########################################
# VERSION:  GIT'ified - now for work at deloitte
# UPDATED:  13/01/2019
# DESCRIP:  local sync (and rolling snapshot) of a nominated CIFS/SMB network share
#   NOTES:  this has been setup initially for CBA gig sync. To add to this, just duplicate ### lines with new target
#           this script relies on
#               1/ installation of unison (file sync utility)... see evernote for my cheatsheet
#               2/ its config file configured, locaton: "/Users/keiran_harris/Library/Application Support/Unison/_CBA.prf"
#               3/ putting::     UNISONLOCALHOSTNAME="pro15" ; export UNISONLOCALHOSTNAME      in .bashrc file (otherwise unison continually thinks its a new sync when my IP/location chanegs)
#  TRICKY:  string handling, "O2 Fileshare" has a space in it which mount_smbfs doesnt like (nor does funtion argument passing) without special handling...
########################################


#GLOBAL VARIABLES (ANNOYING, BUT ....)
O2GIG=""
DAYSOLD=""

source /_KEIRAN/_SCRIPTS/__CONFIG/bigD.conf

#WORK CREDS
USERNAME=$CONF_USERNAME
PASS=$CONF_PASSWORD
SHAREHOST01=$CONF_SHAREHOST01
SHAREFULLPATH01=$CONF_SHAREFULLPATH01
#SPLIT THE FULL PATH, OSX ONLY CREATES THE MOUNT POINT AS THE FINAL FOLDER NAME (ARRAY ELEMENT 01)
ar_SHAREFULLPATH01=(${SHAREFULLPATH01//\// })
SHARELEAFFOLDER=${ar_SHAREFULLPATH01[1]}

#TV CREDS
USERNAME02=$CONF_USERNAME02
PASS02=$CONF_PASSWORD02
SHAREHOST02=$CONF_SHAREHOST02
SHAREFULLPATH02=$CONF_SHAREFULLPATH02

#NAS CREDS
USERNAME03=$CONF_USERNAME03
PASS03=$CONF_PASSWORD03
SHAREHOST03=$CONF_SHAREHOST03
SHAREFULLPATH03=$CONF_SHAREFULLPATH03

#IPs TO PING
GOOGLEHOST="8.8.8.8"
DELOITTEHOST="10.43.96.1"

declare -a ARGUMENTS            #if user enters multiple choices in menu, they are stored here
declare -a CURRENTMOUNTS        #array of our current mounts (as this program sees them).
#--------------------------------------------------------------------------------
#CREATE /tmp/kmount.tmp AND SETUP CURRENTMOUNTS ARRAY (FOR UMOUNTING SELECTED MOUNTS). $1=NAS-NAME/IP
CreateTmpMountFileAndArray () {
    #make a tmp mount file (matching only our remote mounts) to make later operations easier
    mount | grep $1 > /tmp/kmount.tmp

    #setup an array of remote mounts
    i=0
    while read remoteMount allOtherCrap     #allOtherCrap captures everything after first IFS (space)
    do
        CURRENTMOUNTS[$i]=$remoteMount
        i=$i+1
    done </tmp/kmount.tmp
}

#--------------------------------------------------------------------------------
#DISPLAY A MENU
PrintMenu () {
    #GET LAST SYNC TIME FROM FILE
#    while IFS='' read -r line || [[ -n "$line" ]]; do
#        LASTSYNCTIME="$line"
#    done < "/_LOCALDATA/K-WORK/_UNISON-SYNC/_$O2GIG/timestamp.txt"

    #GET LAST SNAP TIME FROM FILE
#    while IFS='' read -r line || [[ -n "$line" ]]; do
#        LASTSNAPTIME="$line"
#    done < "/_LOCALDATA/_SNAPSHOTS/_LANSYNC/_$O2GIG/timestamp.txt"

    clear
#    printf '%s\n' "${ar_SHAREFULLPATH01[@]}"
#    printf "${ar_SHAREFULLPATH01[1]}"
#    printf "$SHAREBASEMOUNTPT01"
#    echo $SHARELEAFFOLDER

    echo "----------- Welcome to the kMENU Program ------------"
    echo "|                                                   |"
#    echo "| O2 CUSTOMER:: $O2GIG                              |"
#    echo "|                                                |"
#    echo "|  (uf) unison-full  [last sync: $LASTSYNCTIME]  |"
#    echo "|  (uc) unison-curr  [last sync: $LASTSYNCTIME]  |"
#    echo "|  ( s) snapshot-bak [last snap: $LASTSNAPTIME]  |"

    echo "|  (sd) sync dtt    smb://ausyd0800/users$/keharris |"
    echo "|  (md) mount dtt   smb://ausyd0800/users$/keharris |"
    echo "|  (mn) mount nas   smb://10.10.10.5/_DATAKEIRAN    |"
    echo "|  (mt) mount tv    smb://10.10.10.100/_TVHDD       |"
    echo "|  (ds) dismount specific                           |"
    echo "|                                                   |"
    echo "|  (pg) ping google   (8.8.8.8)                     |"
    echo "|  (pd) ping deloitte (10.43.96.1)                  |"
    echo "|  (st) speedtest                                   |"
    echo "|                                                   |"
    echo "|  (bh) backup AU10822 to HDD (K_1TB)               |"
    echo "|                                                   |"
    echo "|  (ck) CyOptics kill                               |"
    echo "|  (vk) virus scanner kill                          |"
    echo "|  (vs) virus scanner status                        |"
    echo "|                                                   |"
    echo "|  ( r) refresh (this screen)                       |"
    echo "|                                                   |"
    echo "|  ( q) quit                                        |"
    echo "|                                                   |"
    PrintCurrentMounts
}
#BASED OFF OUR CURRENTMOUNTS ARRAY, LIST OUT OUR MOUNTS
PrintCurrentMounts () {
    echo "------------------CURRENT MOUNTS---------------------"
    #ITERATE THROUGH CURRENTMOUNTS PRINTING IT OUT...
    max=${#CURRENTMOUNTS[*]}    #notation for working out the upper indicie of the array
    for (( k=0; k<$((max)); k=k+1 )); do
        echo "$((k+1)): ${CURRENTMOUNTS[k]}"        #ie print: "1: //keiran_harris@nas.i8/_INSTALL"
    done
    echo "-----------------------------------------------------"
}

#POPULATE GLOBAL ARGUMENTS ARRAY WITH ALL (MAX 3) THE MENU ITEMS THE USER ENTERS
ReadMenuInput () {
    read -p " ENTER CHOICES (MULTIPLE OK, SPACE SEPARATED) ->" choices
    read c1 c2 c3 <<<"$choices"

    #fill the array with choices (perhaps arguments 2 and 3 dont exist)
    ARGUMENTS[0]=$c1
    [[ -n $c2 ]] && ARGUMENTS[1]=$c2
    [[ -n $c3 ]] && ARGUMENTS[2]=$c3
    #if more than 3 arguments are entered, break out of THIS ITERATION of the main menu loop
    myRegEx=".+ .*"
    if [[ "$c3" =~ $myRegEx ]]; then
        echo "max of 3 please!"
        sleep 1
        return 99       #error return
    else
        return 0        #healthy return
    fi
}

#HANDLES ALL THE VALID MENU INPUT
ProcessMenuCommand () {
    case $1 in
        sd) RsyncExpenses
            MountSyncDismount "_$SHARELEAFFOLDER"
#            Snapshot "_$O2GIG"
            ;;
        uc) MountSyncDismount "_$O2GIG" "c"  #'c' in argument $2 is the 'current' flag
#            Snapshot "_$O2GIG"
            ;;
        s)  SnapshotBakAndRotate "_$O2GIG"
            ;;
        md) ProcessMountLogic "${SHAREFULLPATH01}" "$SHAREHOST01" "$USERNAME" "${PASS}" "$SHARELEAFFOLDER"
            ;;
        mt) ProcessMountLogic "${SHAREFULLPATH02}" "$SHAREHOST02" "$USERNAME02" "${PASS02}" "${SHAREFULLPATH02}"
            ;;
        mn) ProcessMountLogic "${SHAREFULLPATH03}" "$SHAREHOST03" "$USERNAME03" "${PASS03}" "${SHAREFULLPATH03}"
            ;;
        d)  unmountNum=1 ; Unmount $unmountNum
            ;;
        ds) UnmountSpecific
            ;;
        st) SpeedTest
            ;;
        bh) BuildRsyncCmd "kdata-work"
            ;;
        pg) pingToHost "$GOOGLEHOST"
            ;;
        pd) pingToHost "$DELOITTEHOST"
            ;;
        ck) VirusOp "CyOptics"
            ;;
        vk) VirusOp "kill"
            ;;
        vs) VirusOp "status"
            ;;
        r)  continue
            ;;
        q)  CleanExit
            ;;
        *)  echo "'$1' not a valid choice"
            sleep 1
            ;;
    esac
}

#--------------------------------------------------------------------------------
BuildRsyncCmd () {
    KLOG=`date "+/Volumes/K_1TB/_RSYNC-BACKUPS/__LOGS/%Y%m%d-%H%M_$1.txt"`
    case $1 in
        kdata-work)
		#KNOTES: -L to follow symlinks
    # insert '--dry-run' into args to test
            KARG=' -L -av --del  --exclude-from /_KEIRAN/_SCRIPTS/__CONFIG/rsync_k_exclude.conf '
            KSRC=' /_KEIRAN/ '
            KDST=' /Volumes/K_1TB/_RSYNC-BACKUPS/_AU10822/ '
            echo "Performing rsync of [$KSRC] to [$KDST] \n....redirecting output to [$KLOG]"
#echo "rsync $KARG $KSRC $KDST | grep -v '/$'"
            rsync $KARG $KSRC $KDST | grep -v '/$' 2>&1  >  $KLOG
            ;;
    esac
    say "backup complete"
    read -p "Backup DONE.... [hit enter to return to menu]"
}

#--------------------------------------------------------------------------------
SpeedTest () {
    speedtest-cli
    read -p "[hit enter to return to menu]"
}
#--------------------------------------------------------------------------------
VirusOp () {
    if [[ $1 == "kill" ]]; then
        sudo /usr/local/McAfee/AntiMalware/VSControl stopoas
        sudo /usr/local/McAfee/AntiMalware/VSControl stop
    fi
    if [[ $1 == "status" ]]; then
        sudo /usr/local/McAfee/AntiMalware/VSControl status
    fi
    if [[ $1 == "CyOptics" ]]; then
        sudo killall -HUP CyOptics
    fi
    sleep 3
}
#--------------------------------------------------------------------------------
#IS HOST PINGING? $1=NAS-NAME/IP
pingToHost () {
    ping -c 4 $1
#    if [[ $? -eq 0 ]]; then
#        return 0        #healthy return
#    else
#        return 99       #failure return
#    fi
}
#--------------------------------------------------------------------------------
#IS HOST PINGING? $1=NAS-NAME/IP
CheckHostIsPinging () {
    #ping -c 1 -t 1 $1 &> /dev/null         #IF USING STANDARD OSX PING
    ping -c 1 -w 1 $1 &> /dev/null          #IF USING PING FROM INETUTILS (t -> w)
    if [[ $? -eq 0 ]]; then
        return 0        #healthy return
    else
        return 99       #failure return
    fi
}

#IS DRIVE ALREADY MOUNTED? $1=SHARENAME
CheckForExistingMounting () {
    #MOUNT_SMBFS COMMAND NEEDS SPECIAL CHARS REPLACED (SPACE IN SHARENAME WITH %20, ! IN PASSWORD WITH %21)
    SHAREFULLPATH01WITHMOUNTESC="${1// /%20}"
    mount | grep $SHAREFULLPATH01WITHMOUNTESC > /dev/null
    if [[ $? -eq 0 ]]; then
        return 0        #healthy return
    else
        return 99       #failure return
    fi
}

#--------------------------------------------------------------------------------
#CREATE LOCAL MOUNT DIR AND MOUNT THE REMOTE SHARE TO IT. $1=SHAREHOST01 $2=SHAREFULLPATH01 $3=USERNAME $4=PASS $5=SHARELEAFFOLDER
MountHost () {
    #SPLIT THE FULL PATH, OSX ONLY CREATES THE MOUNT POINT AS THE FINAL FOLDER NAME (ARRAY ELEMENT 01)
#    ar_SHAREFULLPATH=(${2//\// })
#    SHARELEAFFOLDER=${ar_SHAREFULLPATH[1]}

    MOUNTPOINT="/Volumes/${5}"

    #MOUNT_SMBFS COMMAND NEEDS SPECIAL CHARS REPLACED (! IN PASSWORD WITH %21)(& IN PASSWORD WITH %26)
#    SHAREFULLPATH01WITHMOUNTESC="${2// /%20}"
    PASSWITHMOUNTESC="${4//!/%21}"
    PASSWITHMOUNTESC="${PASSWITHMOUNTESC//&/%26}"
    #CHECK IF LOCAL MOUNT DIRECTORY EXISTS, IF IT DOESNT, CREATE IT
    if [[ -d /Volumes/$5 ]]; then
        echo "local mount point exists, continuing..."
    else
        echo "local mount point /Volumes/$5 doesn't exist, creating..."
        sudo chmod 777 /Volumes/    #NB: on sierra, this requires adding the following to /etc/sudoers   :    keharris ALL = NOPASSWD: /bin/chmod
        mkdir "${MOUNTPOINT}"       #NB: if this mkdir fails (like it did in 10.12 sierra upgrade) you need to: "sudo chmod 777 /Volumes/"
    fi
    #ATTEMPT TO MOUNT THE REMOTE FS
    #NB: correct CLI syntax is:  "mount_smbfs //c920835:<<pass>>@10.208.83.106/O2%20Fileshare /Volumes/O2\ Fileshare"
    echo "Attempting to Mount..."
    #echo mount_smbfs "//${3}:${PASSWITHMOUNTESC}@${1}/${SHAREFULLPATH01WITHMOUNTESC}"  "/Volumes/${5}"
    mount_smbfs "//${3}:${PASSWITHMOUNTESC}@${1}/${SHAREFULLPATH01WITHMOUNTESC}"  "/Volumes/${5}"

    if [[ $? -eq 0 ]]; then
        echo "Mount Success!"
        return 0        #healthy return
    else
        echo "WARNING: Mount Failure!"
        return 99       #failure return
    fi
}

#CORE MOUNTING LOGIC (PING CHECK, ALREADY MOUNTED ETC). $1=SHARENAME, $2=HOSTNAME, $3=USERNAME, $4=PASSWORD, $5=LastFolderNameInMountPath
ProcessMountLogic () {
    echo "share $2 $1 selected..."
    CheckHostIsPinging $2
    #WAS THE PING HEALTH-CHECK OK?
    if [[ $? -eq 0 ]]; then
        echo "host $2 is pinging, checking mounting...."
        CheckForExistingMounting "${1}"
        #ALREADY MOUNTED?
        if [[ $? -eq 0 ]]; then
            echo "mounted already..."
        #NOT YET MOUNTED
        else
            echo "not mounted, attempting to mount..."
            MountHost "$2" "$1" "$3" "$4" "$5"
            #WAS THE MOUNT SUCCESSFUL?
            if [[ $? -eq 0 ]]; then
                #ALL GOOD, CREATE TMP FILE AND ARRAY
                echo "mounted OK."
                say "mownting OK"        #ozzie pronunciation!
                CreateTmpMountFileAndArray $1
            else
                #CLEANUP FAILED MOUNT
                read -p "WARNING: mount failed! Removing /Volumes/$1 [hit enter to ack]"
                rmdir /Volumes/$1
            fi
        fi
    #CANT EVEN PING
    else
        read -p "WARNING: host $2 is NOT pinging, aborting! [hit enter to ack]"
        exit
    fi
    #sleep 1
}


MountSyncDismount() {
    #MOUNT SHARE, IF NECESSARY, REFRESH SCREEN SO WE CAN SEE THE NEW MOUNT...
    echo ""
    echo ""
    echo "--MOUNTING--"
    say "mownting"  &   #continue code execution with &, ozzie pronunciation!
    ProcessMountLogic "${SHAREFULLPATH01}"
    PrintMenu

    #CALL UNISON, TIMESTAMP IT WITH A .TS TEXT FILE IN THE SYNC ROOT
    echo ""
    echo ""
    echo "--UNISON SYNC--"
    say "starting unison"    &   #continue code execution with &
    PRFFILE=$1
    if [[ $2 == "c" ]]; then
        #APPEND PRFFILE WITH 'c' TO POINT AT DIFFERENT UNISION PREF FILE (IE _WBC.prf vs _WBCc.prf)
        PRFFILE=$1$2
    fi
    unison $PRFFILE
    TIMESTAMP=`date "+%Y%m%d-%H%M"`
    UNISONTS="/_KEIRAN/_K-DOCS/_D-WORK/_UNISON-SYNC/$1/timestamp.txt"
    touch $UNISONTS
    echo "$TIMESTAMP" > $UNISONTS
    say "$1 sync complete"

    #DISMOUNT SHARE, REFRESH SCREEN SO WE CAN SEE REMOVED MOUNT...
    echo ""
    echo ""
    echo "--DISMOUNTING--"
    unmountNum=1
    Unmount $unmountNum
    unset CURRENTMOUNTS
    PrintMenu
}

Snapshot () {
    if LastSnapshotWasToday "$1" ; then
        say "last snapshot was today, return to menu" &
    else
        TODAYSDATE=`date "+%Y%m%d"`
        say "last snapshot was "
        if [[ $DAYSOLD -eq TODAYSDATE ]]; then
            say "never"
        elif [[ $DAYSOLD -eq 1 ]]; then
            say "$DAYSOLD day ago"
        else
            say "$DAYSOLD days ago"
        fi
        #SNAPSHOT?
        say "do you wish to snapshot?" &
        for (( i=10; i>0; i--)); do
            printf "\rHit any key to make a snapshot backup ($i seconds till auto-abort)."
            read -s -n 1 -t 1 MYINPUT

            if [ $? -eq 0 ]; then
                echo ""
                echo ""
                echo "--SNAPSHOT,BACKUP,ROTATE--"
                SnapshotBakAndRotate $1
                break
            fi
        done
    fi
}

LastSnapshotWasToday () {
    declare -a LASTSNAPSHOTARRAY    #derived from timestamp.txt in _SNAPSHOT dir, element 0 will be date, element 1 will be time.

    #GET LAST SYNC TIME FROM FILE
    while IFS='' read -r line || [[ -n "$line" ]]; do
        LASTSNAPSHOTTIME="$line"
    done < "/_LOCALDATA/_SNAPSHOTS/_LANSYNC/$1/timestamp.txt"

    IFS='-' read -ra LASTSNAPSHOTARRAY <<< "$LASTSNAPSHOTTIME"
    TODAYSDATE=`date "+%Y%m%d"`
    DAYSOLD=$((TODAYSDATE - LASTSNAPSHOTARRAY[0]))
#    echo "last snapshot: ${LASTSNAPSHOTARRAY[0]}"
#    echo "today: $TODAYSDATE"
#    echo "days old: $DAYSOLD"
#    sleep 5

    if [[ $DAYSOLD -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

RsyncExpenses () {
    echo ""
    echo "RSYNCing gdrive expenses... " ; rsync  -av --del  /_KEIRAN/_K-DOCS/_K-GDRIVE/ScannerPro/    /_KEIRAN/_K-DOCS/_D-WORK/_DELIVERY/_UNISON-SYNC/_keharris/_EXPENSES
}

SnapshotBakAndRotate () {
#    case $1 in
#        _CBA)           ### duplicate as needed.
            echo "aging out oldest snapshot"    ; rm -rf /_LOCALDATA/_SNAPSHOTS/_LANSYNC/$1minus2/
            echo "moving minus1 to minus2"      ; mv  /_LOCALDATA/_SNAPSHOTS/_LANSYNC/$1minus1/    /_LOCALDATA/_SNAPSHOTS/_LANSYNC/$1minus2/
            echo "creating minus1 copy"         ; cp  -a  /_LOCALDATA/_SNAPSHOTS/_LANSYNC/$1/      /_LOCALDATA/_SNAPSHOTS/_LANSYNC/$1minus1/
            echo "RSYNCing latest UNISON sync to snapshot dir" ; rsync  -av --del /_LOCALDATA/K-WORK/_UNISON-SYNC/$1    /_LOCALDATA/_SNAPSHOTS/_LANSYNC/

            #UPDATE TIMESTAMP (OVERWRITE THE TIMESTAMP THAT UNISON PROCESS HAS ALREADY WRITTEN TO HANDLE CASE WHEN THIS FUNCTION IS CALLED ON ITS OWN)
            TIMESTAMP=`date "+%Y%m%d-%H%M"`
            SNAPTS="/_LOCALDATA/_SNAPSHOTS/_LANSYNC/$1/timestamp.txt"
            echo "$TIMESTAMP" > $SNAPTS
            say "snapshot of $1 complete"
#            ;;
#    esac
}

#--------------------------------------------------------------------------------
#IF UNMOUNTING SPECIFIC, CALLED BEFORE UNMOUNT SO SPECIFIC MOUNT CAN BE SELECTED AND PASSED TO IT
UnmountSpecific () {
    clear
    PrintCurrentMounts
    read -p " ENTER UNMOUNT NUMBER ->" unmountNum
    Unmount $unmountNum
}

#ACTUAL UMOUNT (AND ERROR HANDLING). $1="all" OR array index of given share passed in from UnmountSpecific above
Unmount () {
    #SET THE mntPt STRING FOR USE BY UMOUNT SHELL CMD BELOW
    if [[ $1 == "all" ]]; then
        mntPt="/Volumes/_*"
    else
        i=$1-1      #-1 as my mount listing starts at 1, arrays indexes start at 0
        mntPt=${CURRENTMOUNTS[i]}
    fi
    #PERFORM THE ACTUAL UMOUNT
    umount $mntPt &> /dev/null
    if [[ $? -eq 0 ]]; then
        #ALL GOOD
        echo "$1 unmounted successfully..."
        say "dismownted"     #ozzie pronunciation!
    else
        #SOMETHING NOT UNMOUNTING, TRY MORE FORCEABLE
        diskutil unmount $mntPt  > /dev/null
        if [[ $? -eq 0 ]]; then
            read -p "$1 unmounted successfully (had to be forced)... [hit enter to ack]"
        else
            echo "WARNING: something couldn't unmount ok. Heres the open network files (lsof | grep Volumes): "
            lsof | grep Volumes
            read -p "Try again in a few secs [hit enter to ack]"
        fi
    fi
}

#--------------------------------------------------------------------------------
#CLEANEXIT CODE TO BE CALLED BY MENU 'q' OR BY ANY CONCEIVABLE SHELL EVENT (SEE traps BELOW)
CleanExit () {
    #NOT DOING MUCH AT THE MOMENT APART FROM EXITING
    exit 0
}

#FORCE CLEAN EXIT, REGARDLESS OF THE WAY PROGRAM TERMINATES
trap CleanExit SIGHUP      #event 1  (hang up. This is when user kills term window via GUI)
trap CleanExit SIGINT      #event 2  (ctrl+c)
trap CleanExit SIGTERM     #event 15 (terminate signal sent by kill)
trap CleanExit SIGKILL     #event 9  (terminate immediately from kernal)

#--------------------------------------------------------------------------------
#MAIN CODE
if [ "$#" -gt 1 ]; then
    echo "Illegal number of CLI arguments"
    echo "  Usage:      ksync gig       "
    echo "  [ where 'gig' (case insensitive) matches name of ~/Library/Application Support/Unison/_GIG.prf... ]"
    exit
fi

#READ IN CLI ARGUMENT #1 AND ASSIGN TO O2GIG, AND ENSURE IT UPPERCASE
O2GIG="$1"
O2GIG=$(echo $O2GIG | tr 'a-z' 'A-Z')

while true; do
    CreateTmpMountFileAndArray "//"   #NETWORK DRIVES ALWAYS START WITH '//' IN MOUNT OUTPUT
    PrintMenu
    ReadMenuInput
    #MAKE SURE ALL IS OK WITH INPUT BEFORE PROCEEDING, 99 FLAGS AN ISSUE
    if [[ $? -eq 99 ]]; then continue; fi   #'continue' breaks out of THIS ITERATION of the loop

    #FOR EACH MENU INPUT (ON A SINGLE LINE) PROCESS THAT COMMAND
    max=${#ARGUMENTS[*]}    #notation for working out the upper indicie of the array
    for (( k=0; k<$((max)); k=k+1 )); do
        ProcessMenuCommand ${ARGUMENTS[k]}
    done
    unset ARGUMENTS     #destroy arguments array at end of each iteration
    unset CURRENTMOUNTS
done
