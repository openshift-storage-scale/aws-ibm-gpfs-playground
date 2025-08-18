# Scripts to deploy AWS OCP cluster + GPFS

## Installation

Here are the steps to deploy OCP + GPFS. These steps will create an OCP
cluster with 3 master + 3 workers by default and then will create a multiattach
EBS volume and attach it to the three workers.

1. Make sure you have the right ansible dependencies via `ansible-galaxy collection install -r requirements.yml` and also that you have the httpd tools installed
 (httpd-tools on Fedora or `brew install httpd` on MacOSX)
2. Make sure your aws credentials and aws cli are in place and working
3. Make sure you have redhat tokens which enable downloads, token can be obtained at https://console.redhat.com/openshift/downloads
Copy the token to ~/.pullsecret.json

4. Run the following to create an `overrides.yml`. 
```
cat > overrides.yml<<EOF
# ocp_domain: "fusionaccess.devcluster.openshift.com"
ocp_cluster_name: "gpfs-bandini"
gpfs_volume_name: "bandini-volume"
# ocp_worker_count: 3
# ocp_worker_type: "m5.2xlarge"
# ocp_master_count: 3
# ocp_master_type: "m5.2xlarge"
# ocp_az: "eu-central-1a"
# ocp_region: "eu-central-1"

# gpfs_version: "v5.2.2.x"
# ssh_pubkey: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO8CumOo7uGDhSG5gzRdMkej/dBZ3YhhpKweKeyW+iCK michele@oshie"
EOF
```

Change it by uncommenting and tweaking at least the following lines: use the value set in the aws cert and aws config
   - `ocp_domain`
   - `ocp_cluster_name`
   - `gpfs_volume_name`
   - `ocp_az`
   - `ocp_region`
5. Make sure you read `group_vars/all` and have all the files with the secret material done.  
   
6. Run `make ocp-clients`. This will download the needed oc + openshift-install version  
   in your home folder under `~/aws-gpfs-playground/<ocp_version>`  
   you might need to add this path to your bash PATH or copy to /usr/bin folder  

7. Run `make install` to install the openshift-fusion-access operator
   
8. Once the installation is complete, you can retrieve the cluster access information from the installation log file located at:
~/aws-gpfs-playground/ocp_install_files/.openshift_install.log

Look for the section in the log after the "Install complete!" message. The log will contain the following key details:
- Kubeconfig: The path to your configuration file.
- OpenShift web-console: The URL for the OpenShift web console in AWS.
- Login Credentials: The username and password to log in to the web console.



## Deletion

To delete the cluster and the EBS volume, run `make destroy`

## Health Check

Run `make gpfs-health` to run some GPFS healthcheck commands

## Delete GPFS objects

Run `make gpfs-cleanup` to remove all the gpfs objects we know about
