# Scripts to deploy AWS OCP cluster + GPFS

## Tear up

Here are the steps to deploy OCP + GPFS. These steps will create an OCP
cluster with 3 master + 3 workers by default and then will create a multi-attach
EBS volume and attach it to the three workers.

1. Make sure you have the right ansible dependencies via `ansible-galaxy collection install -r requirements.yml` and also that you have the httpd tools installed
   (httpd-tools on Fedora or `brew install httpd` on MacOS)
2. Make sure your aws credentials and aws cli are in place and working
3. Make sure you have redhat tokens which enable downloads, token can be obtained at https://console.redhat.com/openshift/downloads
4. Copy the token to ~/.pullsecret.json. The file should be in the following format:

```
{
  "auths": {
    "cloud.openshift.com": {
      "auth": "YOUR_TOKEN_HERE",
      "email": "you@example.com"
    },
    "quay.io": {
      "auth": "YOUR_TOKEN_HERE",
      "email": "you@example.com"
    },
    "registry.redhat.io": {
      "auth": "YOUR_TOKEN_HERE",
      "email": "you@example.com"
    }
  }
}
```

5. Run the following to create an `overrides.yml`.

```
cat << EOF > overrides.yml
# ocp_domain: "fusionaccess.devcluster.openshift.com"
ocp_cluster_name: "gpfs-<your-user-name>"
gpfs_volume_name: "<your-user-name>-volume"
# ocp_worker_count: 3
# ocp_worker_type: "m5.2xlarge"
# ocp_master_count: 3
# ocp_master_type: "m5.2xlarge"
# ocp_az: "eu-central-1a"
# ocp_region: "eu-central-1"

# gpfs_version: "v5.2.3.x"
# ssh_pubkey: "ssh-ed25519 AAAAC3... john.doe@rh.com"
EOF
```

Change it by uncommenting and tweaking at least the following lines.

- `ocp_domain`
- `ocp_cluster_name`
- `gpfs_volume_name`
- `ocp_az`
- `ocp_region`

6. Make sure you read `group_vars/all` and have all the files with the secret material done.
7. Run `make ocp-clients`. This will download the needed oc and openshift-install version in your home folder under ~/aws-gpfs-playground/<ocp_version>. You might need to add this path to your bash PATH or copy it to the /usr/bin folder.

8. Run `make install` to install the openshift-fusion-access operator
   
   > **⏱️ Execution Time:** The `make install` process takes approximately **40-45 minutes** to complete.  
   > Based on historical runs, expect the cluster installation step alone to take around 40-44 minutes.  
   > This is normal and includes provisioning AWS infrastructure, bootstrapping OpenShift, and configuring the cluster.

9. Once the installation is complete, you can retrieve the cluster access information from the installation log file located at:
   ~/aws-gpfs-playground/ocp_install_files/.openshift_install.log

Look for the section in the log after the "Install complete!" message. The log will contain the following key details:

- KUBECONFIG File Path: The path for the Kube Config file.
- OpenShift web-console: The URL for the OpenShift web console in AWS.
- Login Credentials: The username and password to log in to the web console.

## Tear down

To delete the cluster and the EBS volume, run `make destroy`

## Health Check

Run `make gpfs-health` to run some GPFS healthcheck commands

## Delete GPFS objects

Run `make gpfs-cleanup` to remove all the gpfs objects we know about

## Add a new EBS volume to a running OCP cluster

To add a new EBS volume to a specific set of EC2 instances in your running OpenShift cluster, you can use the `ebs-add.yml` playbook. This playbook is conveniently aliased via `make ebs-add` for ease of use.

### Usage

1. **Specify the target instances**  
   You can target specific EC2 instances by providing their instance IDs or by defining a filter to select them based on tags or other attributes.

   - **Using instance IDs**:  
     Create or edit your `overrides.yml` file and set the `instance_ids` variable with a list of EC2 instance IDs:
     ```yaml
     instance_ids:
       - "i-0123456789abcdef0"
       - "i-fedcba9876543210f"
     ```
     > **Note:** If you specify `instance_ids`, the playbook will attach the new EBS volume to these instances.

   - **Using a filter**:  
     Alternatively, you can use `instance_filter` to select instances by tag or other criteria:
     ```yaml
     instance_filter:
       "tag:Name": "my-cluster-name*worker*"
       "instance-state-name": "running"
     ```
     > If `instance_ids` is empty, the playbook will use `instance_filter` to find matching instances.

2. **Override other variables as needed**  
   The playbook supports many overridable variables, such as `volume_size`, `volume_type`, `multi_attach`, `iops`, `throughput`, and more.  
   For example, to create a 200 GiB `gp3` volume:
   ```yaml
   volume_size: 200
   volume_type: "gp3"
   throughput: 125
   ```

   > **Tip:** Check out the `playbooks/ebs-add.yml` file to see the full list of variables you can override to customize the volume and attachment behavior.

3. **Run the playbook**  
   Use the provided Makefile target to run the playbook:
   ```
   make ebs-add
   ```

   This will create and attach the EBS volume to the specified instances using your current `overrides.yml` settings.

## Remove an existing EBS volume

To remove an existing EBS volume attached to a set of EC2 instances, you can use the `ebs-remove.yml` playbook. This playbook is aliased via `make ebs-remove` for convenience.

### Usage

1. **Identify the EBS volume to remove**  
   You need the EBS volume ID (e.g., `vol-0123456789abcdef0`) that you wish to detach and delete. You can find this in the AWS Console or by using the AWS CLI.

2. **Set the `volume_id` variable**  
   Specify the volume ID in your `overrides.yml` file:
   ```yaml
   volume_id: "vol-0123456789abcdef0"
   ```
   Alternatively, you can pass it directly on the command line:
   ```
   EXTRA_VARS="-e volume_id=vol-0123456789abcdef0" make ebs-remove
   ```

3. **Run the playbook**  
   Use the provided Makefile target to execute the removal:
   ```
   make ebs-remove
   ```
   This will:
   - Validate that the volume exists.
   - Detach it from any attached instances.
   - Wait for the volume to become available.
   - Delete the volume.

    > **Caution:** Deleting an EBS volume is irreversible. Ensure you have backups or snapshots if you need to retain the data.

> **Note:** You can review and customize the removal process by editing `playbooks/ebs-remove.yml`.



