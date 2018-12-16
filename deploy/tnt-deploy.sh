#!/bin/bash
vp_conf(){
  cat secrets.json | tr '\n' ' ' | python -c "import json,sys; o=json.loads(raw_input()); [sys.stdout.write(k+' '+str(v)+'\n') for k,v in o['nodes'][int('$1')].items()]" \
  | grep $2 | cut -d' ' -f2
}

tnt_install(){
  target_file_path='tnt-install.sh'
  data_dir='/home/root/TNT'
  vp=$1
  username=$(vp_conf $vp username)
  ip=$(vp_conf $vp IP_addr)
  ssh_port=$(vp_conf $vp port)
  printf -v password "%q" "$(vp_conf $vp password)"

  expect -c "set timeout -1
  spawn ssh $username@$ip -p $ssh_port \"mkdir -p $data_dir\"
  expect {
  \"*yes/no\" { send \"yes\r\"; exp_continue }
  \"*password:\" {send \"$password\r\"}
  }
  expect eof"

  expect -c "set timeout -1
  spawn scp -P $ssh_port $target_file_path $username@$ip:$data_dir
  expect -re \".*password.*\" {send \"$password\r\"}
  expect eof"

  expect -c "set timeout -1
  spawn ssh $username@$ip -p $ssh_port \"sh $data_dir/tnt-install.sh\"
  expect -re \".*password.*\" {send \"$password\r\"}
  expect eof"
}

for i in `seq 0 2`; do
  echo -e "\033[32m[ VP#$i install sc_tnt ]\033[0m"
  tnt_install $i
done
