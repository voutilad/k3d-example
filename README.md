# A k3d Example
> From 0 to a Producer app in k3s in a few minutes!

## Prerequisites
Make sure to install:

- k3d: https://k3d.io
- helm: https://helm.sh
- kubectl: https://kubernetes.io/docs/tasks/tools/#kubectl

You need a machine with ~12 GiB of free memory.

## One Command to Rule them All
If you're lazy, just run the included shell script:

```
$ ./go.sh
```

## What's it doing?
1. It installs a 3-node k3s cluster using k3d and enables a local
   Docker registry.
2. It updates Helm repos for Redpanda dependencies.
3. It installs cert-manager via Helm (required for Redpanda).
4. It installs a 3-broker cluster of Redpanda.
5. It configures a sample topic in Redpanda, replicated across all
   brokers.
6. It builds a Docker image for the includes sample Kafka producer
   ([./client.py](client.py)) and deploys it to the local registry.
7. It runs the app within the k3s cluster to produce same data into
   the topic.
