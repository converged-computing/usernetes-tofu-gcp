# Usernetes on Google Cloud

> This is intended to be a basic exampel.

but we are going to test out [generation 2 here](https://github.com/rootless-containers/usernetes/pull/287).

# Usage

## Build images

Make note that the machine types should be compatible with those you chose in [build-images](../../build-images/)
First, edit variables in [basic.tfvars](basic.tfvars). This will determine number of instances, name, etc.

## Deploy

Initialize the deployment with the command:

```bash
$ terraform init
```

I find it's easiest to export my Google project in the environment for any terraform configs
that mysteriously need it.

```bash
export GOOGLE_PROJECT=$(gcloud config get-value core/project)
```

You'll want to inspect basic.tfvars and change for your use case (or keep as is for a small debugging cluster). Then:

```bash
$ make
```

And inspect the [Makefile](Makefile) to see the terraform commands we apply
to init, format, validate, and deploy. The deploy will setup networking and all the instances! Note that
you can change any of the `-var` values to be appropriate for your environment.
Verify that the cluster is up. You can shell into any compute node.

<details>

<summary>Extra Debugging Details</summary>

```bash
gcloud compute ssh usernetes-compute-001 --zone us-central1-a
```

You can check the startup scripts to make sure that everything finished.

```bash
sudo journalctl -u google-startup-scripts.service
```

Note that I logged into all three nodes to ensure the home was created (I do it backwards so I finish up on 001):

</details>

I would give a few minutes for the boot script to run. next we are going to init the NFS mount
by running ssh as our user, and changing variables in `/etc/sub(u|g)id`

```bash
for i in 1 2 3; do
  instance=gffw-compute-a-00${i}
  login_user=$(gcloud compute ssh $instance --zone us-central1-a -- whoami)
done
echo "Found login user ${login_user}"
```

Next change the uid/gid this might vary for you - change the usernames based on the users you have)

```bash
for i in 1 2 3; do
  instance=gffw-compute-a-00${i}
  gcloud compute ssh $instance --zone us-central1-a -- sudo sed -i "s/sochat1_llnlgov/sochat1_llnl_gov/g" /etc/subuid
  gcloud compute ssh $instance --zone us-central1-a -- sudo sed -i "s/sochat1_llnlgov/sochat1_llnl_gov/g" /etc/subgid
done
```

One sanity check:

```bash
$ gcloud compute ssh $instance --zone us-central1-a -- cat /etc/subgid
```

For the rest of this experiment we will work to setup each node. Since there are different steps per node,
we are going to clone usernetes to a non-shared location. 

```bash
$ gcloud compute ssh usernetes-compute-001 --zone us-central1-a
```

**TODO**
