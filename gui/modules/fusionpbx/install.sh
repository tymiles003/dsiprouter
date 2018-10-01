#!/usr/bin/env bash
#set -x
ENABLED=1 # ENABLED=1 --> install, ENABLED=0 --> do nothing, ENABLED=-1 uninstall

function install {

    if [[ "$DISTRO" == "debian" ]]; then
        apt-get install -y \
            apt-transport-https \
            ca-certificates \
            software-properties-common

        curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -

        add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/debian \
        $(lsb_release -cs) \
        stable"

        apt-get update -y

        apt-get install -y docker-ce
        if [ $? == 0 ]; then
            echo "Docker is installed"
        fi

    elif [[ "$DISTRO" == "centos" ]]; then
        yum install -y ca-certificates
#        CA_CERT_DIR=$(dirname $(find / -name '*ca-bundle.crt'))
#        cp -f ${CA_CERT_DIR}/ca-bundle.crt ${CA_CERT_DIR}/ca-bundle.bak
#        curl http://curl.haxx.se/ca/cacert.pem -o ${CA_CERT_DIR}/ca-bundle.crt
#        update-ca-trust force-enable
#        update-ca-trust extract

        yum install -y yum-utils device-mapper-persistent-data lvm2
        yum remove -y docker\*
        yum-config-manager -y --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum-config-manager -y --enable docker-ce-stable
        yum install -y docker-ce

        if [ $? == 0 ]; then
            echo "Docker is installed"
        fi
    fi

    systemctl enable docker.service
    systemctl start docker

    firewall-cmd --permanent --zone=public --add-port=80/tcp
    firewall-cmd --permanent --zone=public --add-port=443/tcp
    firewall-cmd --reload

    # Install Nginx container
    abspath=$(pwd)/gui/modules/fusionpbx
    echo "FusionPBX Path: $abspath"
    docker create nginx
    #docker run --name docker-nginx -p 80:80  -v ${abspath}/dsiprouter.nginx:/etc/nginx/conf.d/default.conf  -d nginx

    echo "FusionPBX module installed"
}

function uninstall {

	# Forcefully stop all docker containers and remove them
	docker ps -a -q > /dev/null
	if [ $? == 1 ]; then
		docker rm -f $(docker ps -a -q) > /dev/null
		echo "Stopped and removed all docker containers"
	else
		echo "No docker containers to remove"
	fi

    if [[ "$DISTRO" == "debian" ]]; then
        # Can't remove packages because it removes python3-pip package
        #apt-get remove -y \
        #apt-transport-https \
        #ca-certificates
        #software-properties-common

        # Remove Docker Engine
        apt-get remove -y docker-ce
        if [ $? == 0 ]; then
            echo "Removed the docker engine"
        fi

        # Remove docker repository
        #sed -i 's|https://download\.docker\.com|d|' /etc/apt/sources.list
        #if [ $? == 0 ]; then
        #	echo "Removed the docker repository"
        #fi

        # Stop trusting the docker key
        key=`apt-key list | grep -B 1 docker | head -n1`
        apt-key del $key

    elif [[ "$DISTRO" == "centos" ]]; then
        yum remove -y ca-certificates

        yum remove -y device-mapper-persistent-data lvm2
        yum remove -y docker-ce
        if [ $? == 0 ]; then
            echo "Removed the docker engine"
        fi

        # Remove the repos
        rm -f /etc/yum.repos.d/docker-ce*
        yum clean all
    fi

    firewall-cmd --permanent --zone=public --remove-port=80/tcp
    firewall-cmd --permanent --zone=public --remove-port=443/tcp
    firewall-cmd --reload

    echo "FusionPBX module uninstalled"
}

function main {
    if [[ ${ENABLED} -eq 1 ]]; then
        install
    elif [[ ${ENABLED} -eq -1 ]]; then
        uninstall
    else
        exit 0
    fi
}

main
