## ansible-role-lstu

An ansible role deploy the application on host machine(Ubuntu 20.04)

## terraform-aws-lstu

A terraform plan creates necessary AWS infrastructure and deploy the lstu. This terraform plan uses the `lstu_startup.sh` script to deploy application on AWS and also uses above ansible roles `ansible-role-lstu` to configure the application on AWS.