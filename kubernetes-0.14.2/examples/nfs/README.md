# Example of NFS volume

See [nfs-web-pod.yaml](nfs-web-pod.yaml) for a quick example, how to use NFS volume
in a pod.

## Complete setup

The example below shows how to export a NFS share from a pod and import it
into another one.

### NFS server part

Define [NFS server pod](nfs-server-pod.yaml) and
[NFS service](nfs-server-service.yaml):

    $ kubectl create -f nfs-server-pod.yaml
    $ kubectl create -f nfs-server-service.yaml

The server exports `/mnt/data` directory as `/` (fsid=0). The directory contains
dummy `index.html`. Wait until the pod is running!

### NFS client

[WEB server pod](nfs-web-pod.yaml) uses the NFS share exported above as a NFS
volume and runs simple web server on it. The pod assumes your DNS is configured
and the NFS service is reachable as `nfs-server.default.kube.local`. Edit the
yaml file to supply another name or directly its IP address (use
`kubectl get services` to get it).

Define the pod:

    $ kubectl create -f nfs-web-pod.yaml

Now the pod serves `index.html` from the NFS server:

    $ curl http://<the container IP address>/
    Hello World!
