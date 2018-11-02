#!/bin/bash 

PRE1='pre-des1'
PRE2='pre-des2'
APL='pro-apl'
EST='pro-est'
MUX='pro-mux'
FLO='flow'
MER='merc'
V7MO='v7mo'
V7ME='v7me'

SVC_PRE1='22.2.15.231'
SVC_PRE2='22.2.16.80'
SVC_APL='22.2.1.19'
SVC_EST='22.2.1.37'
SVC_MUX='22.2.1.156'
SVC_FLOW='22.2.66.20'
SVC_MERC='22.2.8.48'

V7000_O='180.16.15.104'
V7000_E='180.16.15.99'

MON_USR='x101513'
HOST_INFO_ARGS=5
VDISK_INFO_ARGS=6

MDISK_GRPS_CAP_FIELDS='6 8 9 10 11 17 18 19'
MDISK_GRPS_LAST='19'
MDISKS_COLMS='id,name,status,mdisk count,vdisk count,total capacity (GB),extent size (MB),free capacity (GB),virtual capacity (GB),used capacity (GB),real used capacity(GB),overallocation (%),warning,easy tier,easy tier status,compression active,compression virtual capacity (GB),compression compressed capacity (GB),compression uncompressed capacity (GB)'
HOST_COLMS='host id,host name,status,wwpn1,wwpn2,io_grps'
VDISK_COLMS='id,name,IO_group_id,IO_group_name,status,primary_mdisk_grp,secondary_mdisk_grp,primary_copy_id,secondary_copy_id,capacity,vdisk_UID,copy_count,se_copy_count'
MDISKGRP_F="$HOME/$1_mdiskgrps.csv"
VDISKS_LIST_F="$HOME/$1_vdisks.csv"
HOSTS_LIST_F="$HOME/$1_hosts.csv"
VDISK_MAP_F="$HOME/$1_mapping.csv"
PORTS_LIST_F="$HOME/$1_ports.csv"
FC_MAP_F="$HOME/$1_fcmap.csv"
RC_CG_F="$HOME/$1_rccg.csv"
EVENTS_F="$HOME/$1_events.csv"
FABRIC_F="$HOME/$1_fabric.csv"
STATS_F="$HOME/$1_stats.csv"
STATS_PARAMS='-history cpu_pc:compression_cpu_pc:fc_mb:write_cache_pc:total_cache_pc:vdisk_mb:mdisk_mb:vdisk_r_mb:vdisk_w_mb:vdisk_r_ms:vdisk_w_ms'
COLUMNS='VDISK ID,VDISK NAME,CAPACITY,UUID,PRIMARY POOL,SECONDARY POOL,HOST ID,HOST NAME,HOST STATUS,WWPN1,WWPN2'
LOG='/home/ipa/admx101513/scripts/log'

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



get_usage_example (){

    echo
    echo "Example usage:"
    echo "$0 ( pre-des1 | pre-des2 | pro-apl | pro-est | pro-mux | flow | merc | v7mo | v7me)"
    return 0
}

check_parameters (){

    case $1 in
    
        'pre-des1'|'pre-des2'|'pro-apl'|'pro-est'|'pro-mux'|'flow'|'merc'|'v7mo'|'v7me')
                    return 1
                    ;;
        *)
            get_usage_example
            ;;
       
    esac

    return 0
}

get_svc (){

    case $1 in

        'pre-des1')
                    echo $SVC_PRE1
                    return 1
                    ;;
        'pre-des2')
                    echo $SVC_PRE2
                    return 1
                    ;;
        'pro-apl')
                    echo $SVC_APL
                    return 1
                    ;;
        'pro-est')
                    echo $SVC_EST
                    return 1
                    ;;
        'pro-mux')
                    echo $SVC_MUX
                    return 1
                    ;;
        'flow')
                    echo $SVC_FLOW
                    return 1
                    ;;
        'merc')
                    echo $SVC_MERC
                    return 1
                    ;;
        'v7mo')
                    echo $V7000_O
                    return 1
                    ;;
        'v7me')
                    echo $V7000_E
                    return 1
                    ;;
        *)
                    echo ''
                    ;;
                    
    esac
    
    return 0
}

valid_status (){

    case $1 in 

        'online'|'offline'|'degraded')
                                    return 0
                                    ;;
        *)
            return 1
    esac
    return 1
}

to_GB (){

    capacity=`echo "$1 / 1073741824" | bc`
    echo $capacity
    return 0
}

is_a_number (){

    str=`echo $1 | sed s/[a-zA-Z_-'.']*//g`
    if `echo $str | grep -q -E "[0-9]"`
    then
        return 0
    fi
    return 1
}

get_mdisk_groups (){

    svc_ip=$1
    output_file=$2
    dom=$3
    temp_file=`mktemp $0_mdiskgrps.XXXX`
    
    ssh $MON_USR@$svc_ip lsmdiskgrp -bytes -delim ,| grep -v -E "^id" 1> $temp_file 2> /dev/null

    echo $MDISKS_COLMS > $output_file
    
    while read line 
    do 
        for field in `echo 6 8 9 10 11 17 18 19`
        do
            capacity=`echo $line | cut -d, -f$field`
            
            if is_a_number $capacity
            then
                
                gb=`to_GB $capacity`
                capacity=$gb                
                prev=`echo $line | cut -d, -f1-$(($field-1))`
                prev="$prev,"
                if test $field -eq $MDISK_GRPS_LAST
                then
                    post=''
                else
                    post=`echo $line | cut -d, -f$(($field+1))-$MDISK_GRP_LAST`
                    post=",$post"
                fi

                line="$prev$capacity$post"
            fi
        done

        echo $line >> $output_file
        
    done < $temp_file

    rm -f $temp_file &> /dev/null
    return 0
}

get_host_info (){

    my_host=$1
    svc_ip=$2
    host_info=`ssh $MON_USR@$svc_ip lshost $my_host | grep -i -E "id|name|WWPN|status" | awk '{print $2}' | xargs | sed s/' '/,/g`
    n_args=`echo $host_info | sed s/"[a-zA-Z0-9]*"//g | wc -m`
  
    
    if `test $n_args != $HOST_INFO_ARGS`
    then
        final_host_info=`echo $host_info | awk -F, '{print $1","$2","$3","$4",none"}'`
        host_info=$final_host_info
    fi

    echo  $host_info
    return 0
}

get_host_iogrps (){

    host=$1
    svc_ip=$2
   
    iogrps=`ssh -n $MON_USR@$svc_ip lshostiogrp $host | grep -v -i "^id" | awk '{print $2}' | xargs | sed s/' '/':'/g`
    echo $iogrps
    return 0
}

get_iogrps (){

    svc_ip=$1
    output_f=$2
    out=`ssh -n $MON_USR@$svc_ip lsiogrp -delim=, > "$output_f"`
    return 0
}

get_remote_copy_cg (){

    svc_ip=$1
    output_f=$2
    out=`ssh -n $MON_USR@$svc_ip lsrcconsistgrp -delim=, > "$output_f"`
    return 0
}

get_flash_copy_map (){

    svc_ip=$1
    output_f=$2
    out=`ssh -n $MON_USR@$svc_ip lsfcmap -delim=, > "$output_f"`
    return 0
}

get_ports (){

    svc_ip=$1
    output_f=$2
    out=`ssh -n $MON_USR@$svc_ip lsportfc -delim=, > "$output_f"`
    return 0
}

get_events (){

    svc_ip=$1
    output_f=$2
    out=`ssh -n $MON_USR@$svc_ip lseventlog -delim=# > "$output_f"`
    return 0
}

get_hosts (){

    svc_ip=$1
    output_f=$2
    hosts=`ssh -n $MON_USR@$svc_ip lshost | grep -v -i "^id" | awk '{print $2}' | xargs`

    echo $HOST_COLMS > "$output_f"    

    for host in `echo $hosts`
    do
        info=`get_host_info $host $svc_ip`
        iogrps=`get_host_iogrps $host $svc_ip`
        echo "$info,$iogrps" >> "$output_f"
    done 
    return 0
}

get_vdisk_list (){

    svc_ip=$1
    vdisk_list_file=$2
    output_f=$3
    tempf=`mktemp copies_vdiskcopy.XXX`

    while read line
    do
        neatline=''
        if `echo $line | grep -i -v -q "^id," &> /dev/null`
        then
            neatline=`echo $line | cut -d, --output-delimiter="," -f"1-5,7-8,14,16,18"`
            vdisk=`echo $neatline | awk -F, '{print $2}'`
            ssh -n $MON_USR@$svc_ip lsvdiskcopy -delim , $vdisk | grep -v "^vdisk_id" > $tempf
            mdiskgrps=`cat $tempf | awk -F, '{print $8}' | xargs | awk '{gsub(/ /,","); print}'`
            primary=`cat $tempf | awk -F, '{print $6}' | xargs | awk '{gsub(/ /,","); print}'`
            copy_ids=`cat $tempf | awk -F, '{print $3}' | xargs | awk '{gsub(/ /,","); print}'`
            if `test "$primary" != "yes,no"`
            then
                mdiskgrps=`echo $mdiskgrps | awk -F, '{print $2","$1}'`    
                copy_ids=`echo $copy_ids | awk -F, '{print $2","$1}'`
            fi
            neatline=`echo $neatline | awk -v mdgs="$mdiskgrps" -v cp_ids="$copy_ids" '{gsub(/many/,mdgs","cp_ids);print}'`
            echo $neatline >> $output_f
        fi

    done < $vdisk_list_file

    rm $tempf
    cat $output_f | grep -i -v "^id," | sort | uniq > $vdisk_list_file
    echo $VDISK_COLMS > $output_f
    cat $vdisk_list_file >> $output_f

    return 0
}

get_vdisk (){

    vol=$1
    svc_ip=$2
    output_file=$3

    case $vol in

        'all')
                ssh $MON_USR@$svc_ip lsvdisk -delim , 1> $output_file 2> /dev/null
                return 0
                ;;
        *)
                ssh $MON_USR@$svc_ip lsvdisk $vol -delim , 1> $output_file 2> /dev/null 
                return 0

    esac
    
    return 1
}

get_vdisk_mapping (){

    svc_ip=$1
    output_f=$2
    out=`ssh -n $MON_USR@$svc_ip lshostvdiskmap -delim , 1> $output_f 2> /dev/null`
    return 0
     
}

get_fabric (){

    svc_ip=$1
    output_f=$2
    out=`ssh -n $MON_USR@$svc_ip lsfabric -delim=, > "$output_f"`
    return 0
}

get_nodes (){

    svc_ip=$1
    ssh -n $MON_USR@$svc_ip lsnode | grep -v "^id " | awk '{print $2}' | xargs 2> /dev/null
    return 0
}

swap_timestamp (){
#YYMMDDHHMMSS

    stats_file=$1
    
    if `test -r $stats_file` 
    then
        while read line
        do
            timest=`echo $line | awk -F, '{print $3}'`
            hour=`echo $timest | cut -c7-8`
            min=`echo $timest | cut -c9-10`
            sec=`echo $timest | cut -c11-12`
            timest="$hour:$min:$sec"
            echo $line | awk -F',' -v ts=$timest '{print $1","$2","ts","$4","$5}'
        done < "$stats_file"

        return 0
    fi
    return 1
}

get_stats (){

    svc_ip=$1
    output_f=$2
    
    nodes=`get_nodes $svc_ip`
    tmp_file=`mktemp temp_stats.XXXX`    


    for n in `echo $nodes`
    do
        out=`ssh -n $MON_USR@$svc_ip lsnodestats -delim=, "$STATS_PARAMS" $n  >> "$tmp_file"`
    done

    swap_timestamp $tmp_file >> $output_f
   
    rm -f $temp_file 
    return 0
}

log_init (){
    
    mylog=$1

    tput setaf [1-7]
    if ! `test -w $mylog`
    then
        > $mylog
    fi
    return 0
}

log_input (){

    color=$1
    eol=$2
    mylog=$3
    message=$4


    if `test $eol = 'yes'`
    then
        echo $message >> $mylog
        echo "$(tput setaf $color) $message"
        return 1
    else if `test $eol = 'no'`
    then
        echo -n $message >> $mylog
        echo -n "$(tput setaf $color) $message" 
        return 1
    fi
    fi
    return 0
}

initialize_files (){

    rm "$HOME/$1*.csv" &> /dev/null
    touch $MDISKGRP_F
    touch $VDISKS_LIST_F
    touch $HOSTS_LIST_F
    touch $VDISK_MAP_F
    touch $FABRIC_F
    touch $STATS_F
    return 0
}

#MAIN

    log_init $LOG

    if ! check_parameters $1
    then
   
        svc_ip=`get_svc $1`
        vdisks_f=`mktemp $1_vdisks_all.XXXX`

        initialize_files 
        log_input $CYAN 'yes' $LOG "========== Collecting SVC report from $1 =========="

        log_input $WHITE 'no' $mylog 'Retrieving ports information................'
        get_ports $svc_ip $PORTS_LIST_F
        log_input $GREEN 'yes' $mylog 'DONE'

        log_input $WHITE 'no' $mylog 'Retrieving events information...............'
        get_events $svc_ip $EVENTS_F
        log_input $GREEN 'yes' $mylog 'DONE'

        log_input $WHITE 'no' $mylog 'Retrieving mdiskgrps information............'
        get_mdisk_groups $svc_ip $MDISKGRP_F
        log_input $GREEN 'yes' $mylog 'DONE'

        log_input $WHITE 'no' $mylog 'Retrieving vdisks information...............'
        get_vdisk 'all' $svc_ip $vdisks_f
        get_vdisk_list $svc_ip $vdisks_f $VDISKS_LIST_F
        log_input $GREEN 'yes' $mylog 'DONE'

        log_input $WHITE 'no' $mylog 'Retrieving hosts information................'
        get_hosts $svc_ip $HOSTS_LIST_F
        log_input $GREEN 'yes' $mylog 'DONE'

        log_input $WHITE 'no' $mylog 'Retrieving fabric information...............'
        get_fabric $svc_ip $FABRIC_F
        log_input $GREEN 'yes' $mylog 'DONE'

        log_input $WHITE 'no' $mylog 'Retrieving masking information..............'
        get_vdisk_mapping $svc_ip $VDISK_MAP_F
        log_input $GREEN 'yes' $mylog 'DONE'

        log_input $WHITE 'no' $mylog 'Retrieving Flash Copy information...........'
        get_flash_copy_map $svc_ip $FC_MAP_F
        log_input $GREEN 'yes' $mylog 'DONE'

        log_input $WHITE 'no' $mylog 'Retrieving Remote Copy information..........'
        get_remote_copy_cg $svc_ip $RC_CG_F
        log_input $GREEN 'yes' $mylog 'DONE'

        log_input $WHITE 'yes' $LOG 'All the information was collected successfully.'
        rm $vdisks_f
    else
        get_usage_example
    fi
 
