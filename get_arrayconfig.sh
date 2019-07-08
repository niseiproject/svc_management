#!/bin/bash
#############################################################################
#                                                                           #
#   Name: get_arrayconfig.sh                                                #
#   Description: Retrieves configuration file from IBM SVC and              #
#                IBM Storwize V7000.                                        #
#   Last update: 18/06/2019                                                 #
#   Author: Jesus Gomez Uzquiano                                            #
#   Email: jesus.gomez@ext.gruposantander.com                               #
#                                                                           #
#############################################################################

# sh get_arrayconfig -ip <IP> -path <path>


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

USER='admstg'
KEY='/home/admstg/.ssh/id_rsa'
TRIES=3
CONFIG_FILES='svc.config.backup.xml svc.config.backup.log svc.config.backup.sh'

### FUNCTIONS

get_usage_example (){

    echo
    echo "Example usage:"
    echo "$(tput setaf $YELLOW) $0 -ip $(tput setaf $MAGENTA)<IP>$(tput setaf $YELLOW) -path $(tput setaf $MAGENTA)<absolute_path>$(tput setaf $WHITE) -log $(tput setaf $MAGENTA)<log>$(tput setaf $WHITE)"
    return 0
}

is_valid_ip (){

    if `test ${#} -eq 1`
    then

        if `echo ${1} | grep -i -q -E "([0-9]{1,3}\.){3}[0-9]{1,3}$"`
        then
            return 0
        fi
    fi
    return 1
}

is_valid_path (){

    if `test ${#} -eq 1`
    then

        if `test -d ${1}`
        then
            return 0
        fi
    fi
    return 1
}

is_valid_file (){

    if `test ${#} -eq 1`
    then

        if `echo ${1} | grep -i -q -E "([/[:alnum:]_-.]{1,}){1,}"`
        then
            return 0
        fi
    fi
    return 1
}


check_parameters(){

    if `test ${#} -eq 6`
    then

        if `is_valid_ip ${2}` &&  `is_valid_path ${4}` && `is_valid_file ${6}`
        then
            return 0
        fi
    fi
    return 1
}

get_name(){

    #dig -x 22.2.1.156 | grep -A1 -i answer | grep -i ptr | awk '{print $5}'
    ip=${1}
    host=''
    if `is_valid_ip ${ip}` && `check_array ${ip}`
    then
        host=`dig -x ${ip} | grep -A1 -i answer | grep -i ptr | awk '{gsub(".$","");gsub(/\./,"_");print $5}'`
        echo ${host}
        return 0
    fi
    echo ''
    return 1
}

check_array(){

 ip=${1}
 if `ping -q -c1 ${ip} &> /dev/null`
 then
    return 0
 fi
 return 1
}

run_config_backup(){

    ip=${1}
    log=${2}
    if `ssh ${USER}@${ip} "svcconfig backup -v on" &>> ${log}`
    then
        return 0
    fi
    return 1
}


# MAIN

echo ${@}

if `check_parameters ${@}`
then
    ip=${2}
    directory=${4}
    log=${6}
    > ${log}

    host=`get_name ${ip}`

    if test -n ${host}
    then
        for filename in `echo ${CONFIG_FILES}`
        do
            i=1
            leave=0
            while `test ${i} -le ${TRIES}` && `test ${leave} -eq 0`
            do
                if ! `scp -i ${KEY} ${USER}@${ip}:/tmp/${filename} "${directory}/${host}_${filename}" &> /dev/null`
                then
                    logger -f ${log} "Running configuration backup at ${host}..."
                    echo -n "$(tput setaf $YELLOW)Running configuration backup at ${host}...$(tput setaf $WHITE)"

                    if `run_config_backup ${ip} ${log}`
                    then
                        logger -f ${log} "Configuration backup completed."
                        echo "$(tput setaf $GREEN)DONE $(tput setaf $WHITE)"
                    else
                        logger -f ${log} "Configuration backup failed. Please review log for further details"
                        echo "$(tput setaf $RED)FAILED $(tput setaf $WHITE)"
                        leave=1
                    fi
                else
                    echo "$(tput setaf $YELLOW)File $(tput setaf $MAGENTA)${filename}$(tput setaf $YELLOW) successfully saved in $(tput setaf $CYAN)${directory}$(tput setaf $WHITE)"
                    leave=1
                fi
                i=$((${i}+1))
            done
        done

        nfiles=`ls ${directory} | grep -c "${host}_svc.config.backup*"`

        if `test ${nfiles} -eq 3`
        then
            logger -f ${log} "Compressing files in ${directory}/${host}.tar.gz..."
            echo -n "$(tput setaf $YELLOW)Compressing files in $(tput setaf $MAGENTA)${directory}/${host}.tar.gz$(tput setaf $YELLOW)...$(tput setaf $WHITE)"
            cur_dir=`pwd`
            cd ${directory}
            if  tar -cvzf "${host}.tar.gz" `ls | grep -i -E "${host}_svc.config.backup"| xargs` >> ${log} 2>&1
            then
                logger -f ${log} "Config files successfully packaged!"
                echo "$(tput setaf $GREEN)DONE $(tput setaf $WHITE)"
            else
                logger -f ${log} "Config files could not be packaged. See log file for details."
                echo "$(tput setaf $RED)FAILED $(tput setaf $WHITE)"
            fi
            cd ${cur_dir}
        fi
    fi
else
    get_usage_example
fi