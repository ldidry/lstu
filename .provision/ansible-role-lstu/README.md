Ansible-Role-Lstu
=========
This role installs the and configures lstu on Debian/Ubuntu servers with nginx web server configuration.

Role Variables
-------------- 
| Variable name | Value | Description |
| ------------- | ----- | ----------- |
| `app_dir` | /var/www/lstu | Set the application directory for the best practice |
| `lstu_owner` | www-data | Set the application user for the best practice |
| `lstu_group` | www-data | Set the application group for the best practice |
| `_contact` | contact.example.com | contact option (mandatory), where you have to put some way for the users to contact you. |
| `_secret` | IWIWojnokd | secret  option (mandatory) array of random strings used to encrypt cookies |
| `_project_version` | master | We can chose the project version either Master branch, Dev branch or tag based |
| `_server_name` | IP address (or) CNAME/FQDN | Mention the Server Name for the Nginx configurations |

Sample example of use in a playbook
--------------

The following code has been tested with Ubuntu 20.04

```yaml
 
- name: "install lstu"
  hosts: enter your hosts file
  become: yes
  role:
    - ansible-role-lstu
  vars:
    lstu_owner: "www-data"
    lstu_group: "www-data"
    app_dir: "/var/www/lstu"
    _contact: "contact.example.com"
    _report: "report@example.com"
    _project_version: "master"
    _server_name: "IP address (or) CNAME/FQDN"
```   

Contributing
------------
Don’t hesitate to create a pull request









