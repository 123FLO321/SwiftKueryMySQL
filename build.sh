#!/bin/bash

set -o verbose

MYSQL_V8_PACKAGE="mysql-apt-config_0.8.12-1_all.deb"

if [ -n "${DOCKER_IMAGE}" ]; then

    docker pull ${DOCKER_IMAGE}
    docker run --env CUSTOM_BUILD_SCRIPT --env CUSTOM_TEST_SCRIPT --env SWIFT_SNAPSHOT --env MYSQL_VER -v ${TRAVIS_BUILD_DIR}:${TRAVIS_BUILD_DIR} ${DOCKER_IMAGE} /bin/bash -c "apt-get update && apt-get install -y apt-utils debconf-utils dialog git sudo lsb-release wget libxml2 && cd $TRAVIS_BUILD_DIR && ./build.sh"

else

    if [[ $TRAVIS_OS_NAME == "osx" ]]; then
        if [[ $MYSQL_VER == 5 ]]; then
            mysql --version || { brew update && brew install mysql@5.7 && brew link mysql@5.7 --force && mysql.server start && mysql --version; }
        else
            mysql --version || { brew update && brew install mysql && mysql.server start && mysql --version; }
        fi
    else
        export DEBIAN_FRONTEND="noninteractive"
        if [[ $MYSQL_VER == 5 ]]; then
            mysql --version || { apt-get update && apt-get install -y pkg-config mysql-server libmysqlclient-dev && service mysql start && mysql --version; }
        else
            sudo -E apt-get install -y gnupg
            cd /tmp
            wget https://dev.mysql.com/get/${MYSQL_V8_PACKAGE}
            cd -
            sudo -E echo mysql-apt-config mysql-apt-config/select-server select mysql-8.0 | debconf-set-selections
            sudo -E dpkg -i /tmp/${MYSQL_V8_PACKAGE}
            sudo -E echo mysql-community-server mysql-community-server/root-pass password | debconf-set-selections
            sudo -E apt-get update -y
            sudo -E apt-get install -y pkg-config
            sudo -E apt-get install -q -y mysql-server
            sudo -E apt-get install -y libmysqlclient-dev
            /usr/bin/mysqld_safe --user=mysql &
            sleep 5
            mysql --version
        fi
    fi

    mysql_upgrade -uroot || echo "No need to upgrade"
    mysql -uroot -e "CREATE USER 'swift'@'localhost' IDENTIFIED BY 'kuery';"
    mysql -uroot -e "CREATE DATABASE IF NOT EXISTS test;"
    mysql -uroot -e "GRANT ALL ON test.* TO 'swift'@'localhost';"

    git clone --single-branch https://github.com/IBM-Swift/Package-Builder.git
    ./Package-Builder/build-package.sh -projectDir $(pwd)
fi
