#!/bin/bash
#export LD_PRELOAD=/usr/local/lib/faketime/libfaketime.so.1 
#export FAKETIME="2020-12-24 20:30:00"  #该时间会一直保持不变
#export FAKETIME="@2020-12-24 20:30:00"  #时间会从这里往后递增
exec_target="gameSvr_ddz_2021"
env=$1
if [ env = nil ] ; then
    env="debug"
fi

config_file="config.publish"
if  [ ! -n "$env" ] ;then
    env="publish"
fi

#git pull
#git submodule update --init --recursive

# if [ ! -d "./server/3rd/jemalloc" ]; then
#     tar -xzvf ./server/3rd/jemalloc.tar.gz -C ./server/3rd
#     chmod –R 777 ./server/3rd/jemalloc
# fi 
# cd server && make linux && cd ..
# mv ./server/skynet ./server/$exec_target
# chmod +x ./server/$exec_target

# sudo killall $exec_target
# sleep 1s 
# rm -rf log/*

echo start $env
if [ "$env" = "" ];then
    config_file="config.publish"
else
    config_file="config.$env"
fi

./server/$exec_target $config_file
echo "start server ok in env $env"
