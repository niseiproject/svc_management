#!/bin/bash

THIS_PATH='/home/ipa/admx101513/scripts'

time sh $THIS_PATH/generate_svc_binary_light.sh pre-des2
echo
time sh $THIS_PATH/generate_svc_binary_light.sh pre-des1
echo
time sh $THIS_PATH/generate_svc_binary_light.sh flow
echo
time sh $THIS_PATH/generate_svc_binary_light.sh merc
echo
time sh $THIS_PATH/generate_svc_binary_light.sh pro-mux
echo
time sh $THIS_PATH/generate_svc_binary_light.sh pro-est
echo
time sh $THIS_PATH/generate_svc_binary_light.sh pro-apl
echo
time sh $THIS_PATH/generate_svc_binary_light.sh v7mo
echo
time sh $THIS_PATH/generate_svc_binary_light.sh v7me
echo

