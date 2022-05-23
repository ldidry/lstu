# Terraform-AWS-Deploy

 This terraform plan create the resourcess of EC2 instance

## Terraform Variables
 Edit the `vars.tf` file to add the variables as per your need.

| Variable name | Value | Description |
| ------------- | ----- | ----------- |
| `aws_region` | us-east-1 | Set the region  |
| `vpc_cidr` | 10.0.0.0/16 | Set the cidr value for the vpc |
| `public_subnet_cidr` | 10.0.2.0/24 | Set the cidr value for the public subnet |
| `user` | ubuntu | Set the EC2 instance user name |
| `public_key` | /home/user_name/.ssh/id_rsa_pub | Set the publickey value for the ec2 instance from the host machine |
| `private_key` | /home/user_name/.ssh/id_rsa | Set the private key value for the ec2 instance from the hostmachine |
| `aws_access_key` | AWSACCESSKEY | Enter your aws access key |
| `aws_secrete_key` | AWSSECRETEKEY | Enter your aws secrete key |
| `instance_name` | lstu_app_instance | Set the name for instance |
| `app_dir` | /var/www/lstu | Set the application directory for the best practice |
| `lstu_owner` | www-data | Set the application user for the best practice |
| `lstu_group` | www-data | Set the application group for the best practice |
| `contact` | contact.example.com | contact option (mandatory), where you have to put some way for the users to contact you. |
| `secret` | IWIWojnokd | secret  option (mandatory) array of random strings used to encrypt cookies |
| `project_version` | master | We can chose the project version either Master branch, Dev branch or tag based |

## Usage of terraform plan with lstu deploy script

```sh 
git clone https://github.com/ldidry/lstu

cd lstu/.provision/terraform-aws-lstu

terraform init
terraform plan
terraform apply
```
## Usage of terraform plan with ansible role

- Comment out the below `data template` and `user_data` source in __main.tf__ file

```sh
data "template_file" "init" {
  template = file("./lstu_startup.sh")
  vars = {
    user = var.lstu_owner
    group = var.lstu_group
    directory = var.app_dir
    git_branch = var.project_version
    contact_lstu = var.contact
    secret_lstu = var.secret

  }
}
```
```sh
  user_data          = data.template_file.init.rendered
```

- Add the below provisioner data in __main.tf__ file at the `aws_instance` resource

```sh
  connection          {
    agent            = false
    type             = "ssh"
    host             = aws_instance.ec2_instance.public_dns 
    private_key      = "${file(var.private_key)}"
    user             = "${var.user}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install python3.9 -y",
      ]
  }

  provisioner "local-exec" {
    command = <<EOT
      sleep 120 && \
      > hosts && \
      echo "[lstu]" | tee -a hosts && \
      echo "${aws_instance.ec2_instance.public_ip} ansible_user=${var.user} ansible_ssh_private_key_file=${var.private_key}" | tee -a hosts && \
      export ANSIBLE_HOST_KEY_CHECKING=False && \
      ansible-playbook -u ${var.user} --private-key ${var.private_key} -i hosts site.yaml
    EOT
  } 
 ``` 