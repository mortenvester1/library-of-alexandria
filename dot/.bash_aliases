# activate virtual env in current folder
alias activate-venv='source $(pwd)/venv/bin/activate'

# install, activate virtual env
alias init-venv='__init-venv'
function __init-venv() {
  if [[ `uname -m` == 'arm64' ]] && [[ `uname` == 'Darwin' ]];
  then
    $HOME/.pyenv/versions/$1/bin/python3 -m venv venv;
    source venv/bin/activate;
    pip3 install --upgrade pip setuptools build wheel;
  else
    /usr/bin/python${1} -m venv venv;
    source venv/bin/activate;
    pip3 install --upgrade pip setuptools build wheel;
  fi
}

# get ip of device
alias my-ip="host `hostname` | grep 'has address' | cut -f4 -d' '"

# interactive bash shell for container
alias container-bash='__container-bash'
function __container-bash() {
  docker exec -it $1 /bin/bash;
};

alias python=/usr/bin/python3
alias pip=pip3
