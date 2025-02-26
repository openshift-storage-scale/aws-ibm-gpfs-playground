# Scripts to deploy AWS OCP cluster + GPFS

## Installation

Here are the steps to deploy OCP + GPFS. These steps will create an OCP
cluster with 3 master + 3 workers by default and then will create a multiattach
EBS volume and attach it to the three workers.

1. Make sure you have the right ansible dependencies via `ansible-galaxy collection install -r requirements.yml`
2. Make sure your aws credentials and aws cli are in place and working
3. Tweak override.yml, uncomment and tweak at least the following lines:
   - `ocp_domain`
   - `ocp_cluster_name`
   - `ocp_az`
   - `ocp_region`
4. Make sure you read `group_vars/all` and have all the files with the secret material done
5. Run `make ocp-clients`. This will download the needed oc + openshift-install version
   in your home folder under `~/aws-gpfs-playground/<ocp_version>`
6. Then run either `make install` for the purple operator install or `make classic-install` to use the traditional method via the steps outlined by Mario in his doc.


## Deletion

To delete the cluster and the EBS volume, run `make destroy`

## Health Check

Run `make gpfs-health` to run some GPFS healthcheck commands

## Delete GPFS objects

Run `make gpfs-clean` to remove all the gpfs objects we know about
