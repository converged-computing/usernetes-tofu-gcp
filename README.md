# Terraform Usernetes on Google Cloud

Terraform module to create Google Cloud images for Usernetes development using HashiCorp Packer.
We are going off of the pull request [here](https://github.com/rootless-containers/usernetes/pull/287) 
and development is happening in [examples/basic](examples/basic). Note that we are installing
docker to the VM, and the hope is that this is mostly interchangeable with podman.

## Usage

### Create Google Service Accounts

Create default application credentials (just once):

```bash
$ gcloud auth application-default login
```

this is for packer to find and use.

### Build Images with Packer

Let's first go into [build-images](build-images) to use packer to build our images.
You'll need to first [install packer](https://developer.hashicorp.com/packer/downloads)
You can use the Makefile there to build all (or a select set of) images.
Note that we are currently advocating for using the single bursted image:

```bash
export GOOGLE_PROJECT=myproject
cd ./build-images/compute
```
```bash
$ make
```

### Deploy with Terraform

You can build images under [build-images](build-images) and then use the modules
provided in [tf](tf). An example is provided in [examples/basic](examples/basic).

## License

HPCIC DevTools is distributed under the terms of the MIT license.
All new contributions must be made under this license.

See [LICENSE](https://github.com/converged-computing/cloud-select/blob/main/LICENSE),
[COPYRIGHT](https://github.com/converged-computing/cloud-select/blob/main/COPYRIGHT), and
[NOTICE](https://github.com/converged-computing/cloud-select/blob/main/NOTICE) for details.

SPDX-License-Identifier: (MIT)

LLNL-CODE- 842614
