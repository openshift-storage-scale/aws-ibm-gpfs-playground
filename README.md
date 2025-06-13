# Scripts to deploy AWS OCP cluster + GPFS

## Installation

Here are the steps to deploy OCP + GPFS. These steps will create an OCP
cluster with 3 master + 3 workers by default and then will create a multiattach
EBS volume and attach it to the three workers.

1. Make sure you have the right ansible dependencies via `ansible-galaxy collection install -r requirements.yml` and also that you have the httpd tools installed
 (httpd-tools on Fedora or `brew install httpd` on MacOSX)
2. Make sure your aws credentials and aws cli are in place and working
3. Run the following to create an `overrides.yml`. 
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

Change it by uncommenting and tweaking at least the following lines:
   - `ocp_domain`
   - `ocp_cluster_name`
   - `ocp_az`
   - `ocp_region`
4. Make sure you read `group_vars/all` and have all the files with the secret material done
5. Run `make ocp-clients`. This will download the needed oc + openshift-install version
   in your home folder under `~/aws-gpfs-playground/<ocp_version>`
6. Then run either `make install` for the openshift-fusion-access operator install or `make classic-install` to use the traditional method via the steps outlined by Mario in his doc.


## Deletion

To delete the cluster and the EBS volume, run `make destroy`

## Health Check

Run `make gpfs-health` to run some GPFS healthcheck commands

## Delete GPFS objects

Run `make gpfs-clean` to remove all the gpfs objects we know about

## Test
   - Run `make test-help` to see available tests
   - Run `make test FUNC=<available test functions>` to test a testable function

