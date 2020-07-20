# Terra-share-work
AWS work with Terraform
Work:
provision a load balancer and 3 Nginx web servers using CentOS in the AWS environment 
1) solution using Terraform for provisioning
2) Ansible as a configuration management tool. 
3) Install and configure Nginx on three separate instances including a load balancing solution , with a website including a simple home page and an image (anything will be fine).
4) cluster entry point should be a HTTPS URL, with redirection of HTTP requests to HTTPS (Used self-signed certificate)
5) Servers are adequately secured.
6) Automatic configuration management uses a team user on the hosts with SSH key
7) Configured a cron job which updates security patches every Monday at 10 am and logrotataion setup to compress nginx logs after certain number of days.
