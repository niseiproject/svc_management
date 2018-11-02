#!/bin/bash

APL='pro-apl'
EST='pro-est'
MUX='pro-mux'
P3='pro-p3'

# ENTER SVC IPs, BASED ON YOUR ENVIRONMENT.
SVC_APL='x.x.x.x'
SVC_EST='x.x.x.x'
SVC_MUX='x.x.x.x'
SVC_P3='x.x.x.x'
SVC_PRE1='x.x.x.x'
SVC_PRE2='x.x.x.x'

MON_USR='ENTER YOUR USER HERE'
LOG='PATH TO LOG FILE'

# MAXIMUM NUMBER OF CONCURRENT SYNCHRONIZATIONS
SYNC_SLOTS=10
# VDISK COPY LAUNCHER SCRIPT PATH
LAUNCHER_PATH='PATH TO launch_sync.sh DIRECTORY'
KEY='PATH TO SSL KEY'
ENDING_FILE='PATH TO  POST-MIGRATION LIST OF COMMANDS'

#Num  Colour    #define         R G B

#0    black     COLOR_BLACK     0,0,0
#1    red       COLOR_RED       1,0,0
#2    green     COLOR_GREEN     0,1,0
#3    yellow    COLOR_YELLOW    1,1,0
#4    blue      COLOR_BLUE      0,0,1
#5    magenta   COLOR_MAGENTA   1,0,1
#6    cyan      COLOR_CYAN      0,1,1
#7    white     COLOR_WHITE     1,1,1

WHITE=7
GREEN=2
RED=1
CYAN=6
MAGENTA=5
YELLOW=3

### FUNCTIONS

get_usage_example (){

    echo
    echo "Example usage:"
    echo "$(tput setaf $YELLOW) $0 -svc $(tput setaf $MAGENTA)( pro-apl | pro-est | pro-mux | pro-p3 | pre-des1 | pre-des2)$(tput setaf $YELLOW) -file $(tput setaf $MAGENTA)<vdisk_list_file_absolute_path> $(tput setaf $YELLOW) -speed $(tput setaf $MAGENTA)<0-100>$(tput setaf $WHITE)"
    return 0
}

check_parameters (){
    
    # Check whether there are 6 parameters or not, and if the description of each one is valid
    if `test $# -ne 6`
    then
        echo "$(tput setaf $RED) Error: incorrect number of parameters passed. Please check.$(tput setaf $WHITE)"
        get_usage_example
        return 0
    fi

    case ${2} in

        'pro-apl'|'pro-est'|'pro-mux'|'pro-p3'|'pre-des1'|'pre-des2')

                    if ! `test -r ${4}`
                    then
                        echo "$(tput setaf $RED) Error: vdisk list file not found or not readable. Please check.$(tput setaf $WHITE)"
                        get_usage_example
                        return 0
                    fi

                    if ! `(test ${6} -le 100) && (test ${6} -ge 0)`
                    then
                        echo "$(tput setaf $RED) Error: speed value must be between this range: 0-100. Please check.$(tput setaf $WHITE)"
                        get_usage_example
                        return 0
                    fi

                    return 1
                    ;;
        *)
            echo "$(tput setaf $RED) Error: Unknown SVC ID. Please check.$(tput setaf $WHITE)"
            get_usage_example
            ;;

    esac

    if ! `test -r ${4}`
    then
        echo "$(tput setaf $RED) Error: vdisk list file not found or not readable. Please check.$(tput setaf $WHITE)"
        get_usage_example
        return 0
    fi

    return 0
}

log_init (){

    mylog=${1}

    tput setaf [1-7]
    if ! `test -w ${mylog}`
    then
        > ${mylog}
    fi
    if ! `test -w ${ENDING_FILE}`
    then
        touch ${ENDING_FILE}
    fi
    return 0
}

log_input (){

    color=${1}
    eol=${2}
    mylog=${3}
    message=${4}


    if `test ${eol} = 'yes'`
    then
        echo ${message} >> ${mylog}
        echo "$(tput setaf $color) ${message}$(tput setaf $WHITE)"
        return 1
    else if `test ${eol} = 'no'`
    then
        echo -n ${message} >> ${mylog}
        echo -n "$(tput setaf $color) ${message}$(tput setaf $WHITE)"
        return 1
    fi
    fi
    return 0
}

get_svc (){

    case ${1} in

        'pro-apl')
                    echo ${SVC_APL}
                    return 1
                    ;;
        'pro-est')
                    echo ${SVC_EST}
                    return 1
                    ;;
        'pro-mux')
                    echo ${SVC_MUX}
                    return 1
                    ;;
        'pro-p3')
                    echo ${SVC_P3}
                    return 1
                    ;;
        'pre-des1')
                    echo ${SVC_PRE1}
                    return 1
                    ;;
        'pre-des2')
                    echo ${SVC_PRE2}
                    return 1
                    ;;
        *)
                    echo ''
                    ;;

    esac

    return 0
}

check_vdisk_synchronization (){

    ip=${1}
    syncfile=${2}

    ssh -i ${KEY} ${MON_USR}@${ip} "lsvdisksyncprogress" | grep -v "^vdisk_id" 1> ${syncfile} 2> /dev/null 
    used_slots=`cat ${syncfile} | wc -l`
    echo "${used_slots}"

    if `test ${used_slots} -lt ${SYNC_SLOTS}`
    then
        return 1
    fi

    return 0
}

check_connectivity(){

    ip=${1}
    if `ping -c 3 -w 4 -q ${ip} &> /dev/null`
    then
        return 0
    fi
    return 1
}


### MAIN

    log_init ${LOG}

    check_parameters ${@}
    if  `test $? -eq 1 `
    then
        svc_ip=`get_svc ${2}`
        vdisks_f=${4}
        speed=${6}
        sync_f=`mktemp "/tmp/migrator_vsync.XXXX"`
        temp_f=`mktemp "/tmp/migrator_temp.XXXX"`
        free_slots=0
        #vdisk_id vdisk_name copy_id progress estimated_completion_time
        #0        vdisk0     1       50       070301150000
        #3        vdisk3     0       72       070301132225
        #4        vdisk4     0       22       070301160000
        #8        vdisk8     1       33
       
        if check_connectivity ${svc_ip}
        then
            log_input ${RED} 'no' ${LOG} "${svc_ip} is unreachable. Please check connectivity."
            log_input ${WHITE} 'yes' ${LOG} ''
            exit 1
        fi
 
        log_input ${CYAN} 'yes' ${LOG} "========== Checking vdisk synchronization sessions from ${2} =========="
        log_input ${WHITE} 'yes' ${LOG} '' 
        used_slots=`check_vdisk_synchronization ${svc_ip} ${sync_f}`
        free_slots=`echo "${SYNC_SLOTS} - ${used_slots}" | bc`
        log_input ${WHITE} 'no' ${LOG} 'Synchronization sessions allowed: '
        log_input ${GREEN} 'yes' ${LOG} "${SYNC_SLOTS}"
        log_input ${WHITE} 'no' ${LOG} 'Free sessions:                    '
        log_input ${GREEN} 'yes' ${LOG} "${free_slots}"
        log_input ${WHITE} 'yes' ${LOG} ''
        log_input ${CYAN} 'yes' ${LOG} "==========================================================================="

        lines_left=`cat ${vdisks_f} | wc -l`
        if `test ${lines_left} -eq 0`
        then
            #We're done!
            log_input ${WHITE} 'yes' ${LOG} "No pending copies left. We are done!: `date`"
            exit 0
        fi
 
        if `test ${used_slots} -gt 0`
        then
            log_input ${MAGENTA} 'yes' ${LOG} "Current running sessions at `date`:"
            cat ${sync_f}
        fi
        
        if `test ${free_slots} -gt 0`
        then
            i=1
            last_vdisk=''
            vdisk_name='none'
            mylock=`mktemp lock.XXXX`
            tries=0
            #for i in `seq 1 $free_slots`
            while `(test ${i} -le ${free_slots}) && (test $lines_left -gt 0) && (test ${tries} -lt 3)`
            do
                vdisk_info=`cat ${vdisks_f} | head -n1`
                cat ${vdisks_f} | grep -v "${vdisk_info}" > ${temp_f}
                cat ${temp_f} > ${vdisks_f}
                vdisk_id=`echo ${vdisk_info} | awk '{print $1}'`
                vdisk_name=`echo ${vdisk_info} | awk '{print $2}'`
                vdisk_copy=`echo ${vdisk_info} | awk '{print $4}'`
                vdisk_pool=`echo ${vdisk_info} | awk '{print $3}'`
                compression=`echo ${vdisk_info} | awk '{print $5}'`
                trashbin=`check_vdisk_synchronization ${svc_ip} ${sync_f}`                

                if  `! cat ${sync_f} | grep -i -q ${vdisk_name}`
                then 
                    log_input ${WHITE} 'yes' ${LOG} "launch_sync.sh -svc ${svc_ip} -id ${vdisk_id} -name ${vdisk_name} -copy ${vdisk_copy} -mdiskgrp ${vdisk_pool} -compress ${compression} -speed ${speed}"
                    
                    {
                    flock -e -w5 200    
                    sh "${LAUNCHER_PATH}"/launch_sync.sh -svc "${svc_ip}" -id "${vdisk_id}" -name "${vdisk_name}" -copy "${vdisk_copy}" -mdiskgrp "${vdisk_pool}" -compress "${compression}" -speed "${speed}" -ending ${ENDING_FILE}

                    } 200>${mylock}
                    i=$((${i}+1))
                    tries=0
                    #sleep 1
                else
                    # A copy of this vdisk is being synchronized, so we delay this execution. 
                    log_input ${WHITE} 'yes' ${LOG} "Current vdisk: ${vdisk_name}; has a copy that is already being synchronized. It will be queued at the end of the list "
                    echo ${vdisk_info} >> ${vdisks_f}
                    log_input ${WHITE} 'yes' ${LOG} "This is how the list looks like now:"
                    cat ${vdisks_f}
                    tries=$((${tries}+1))
                fi
                lines_left=`cat $vdisks_f | wc -l`
            done
            rm ${mylock}
        fi
        log_input ${WHITE} 'yes' ${LOG} ''        
        rm ${sync_f}
        rm ${temp_f}
    fi
exit 0
