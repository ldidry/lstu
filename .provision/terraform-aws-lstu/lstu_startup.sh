#!/bin/bash

echo "**********************************************************************"
echo "                                                                     *"
echo "Install dependencies                                                 *"
echo "                                                                     *"
echo "**********************************************************************"

SUDO=sudo
$SUDO apt update
$SUDO apt install jq -y
$SUDO apt install wget -y
$SUDO apt install unzip -y
$SUDO apt install carton -y
$SUDO apt install build-essential -y
$SUDO apt install nginx -y
$SUDO apt install libssl-dev -y
$SUDO apt install libpng-dev -y
$SUDO apt install libio-socket-ssl-perl -y
$SUDO apt install liblwp-protocol-https-perl -y
$SUDO apt install zlib1g-dev -y
$SUDO apt install libmojo-sqlite-perl -y
$SUDO apt install libpq-dev -y

echo "**********************************************************************"
echo "                                                                     *"
echo "Configuring the Application                                          *"
echo "                                                                     *"
echo "**********************************************************************"

sleep 10;
version=$(curl -s https://framagit.org/api/v4/projects/5/releases | jq '.[]' | jq -r '.name' | head -1)
echo $version
pushd ${directory} 
$SUDO wget https://framagit.org/fiat-tux/hat-softwares/lstu/-/archive/$version/lstu-$version.zip
$SUDO unzip lstu-$version.zip
$SUDO chown ${user} lstu-$version
$SUDO chgrp ${group} lstu-$version
pushd lstu-$version


echo "**********************************************************************"
echo "                                                                     *"
echo "Install Carton Packages                                              *"
echo "                                                                     *"
echo "**********************************************************************"

$SUDO carton install --deployment --without=test --without=sqlite --without=mysql

sleep 10;

$SUDO cp lstu.conf.template lstu.conf
$SUDO sed -i 's/127.0.0.1/0.0.0.0/'  lstu.conf
$SUDO sed -i 's/#contact/contact/g' lstu.conf
$SUDO sed -i "s/admin\[at]\example.com/${contact_lstu}/g" lstu.conf
$SUDO sed -i 's/#secret/secret/' -i lstu.conf
$SUDO sed -i "s/fdjsofjoihrei/${secret_lstu}/g" lstu.conf
$SUDO sed -i '89 , 91 s/#/ /g' lstu.conf
$SUDO sed -i '94 , 95 s/#/ /g' lstu.conf
$SUDO sed -i '98 s/#/ /g' lstu.conf




echo "**********************************************************************"
echo "                                                                     *"
echo "Run the Application                                                  *"
echo "                                                                     *"
echo "**********************************************************************"

$SUDO carton exec hypnotoad script/lstu

