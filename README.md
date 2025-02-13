# Scripts to deploy AWS OCP cluster + GPFS

Here are the steps to deploy OCP + GPFS:

1. Make sure you have the right ansible dependencies via `ansible-galaxy collection install -r requirements.yml`
2. Make sure your aws credentials and aws cli are in place and working
3. Tweak override.yml, uncomment and tweak at least the following lines:
   - `ocp_domain`
   - `ocp_cluster_name`
   - `ocp_az`
   - `ocp_region`
4. Run `make ocp-clients`. This will download the needed oc + openshift-install version
   in your home folder under `~/aws-gpfs-playground/<ocp_version>`
5. Then run `make install`
