<!--
Copyright 2014 Google Inc. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

-->
# Live update example
This example demonstrates the usage of Kubernetes to perform a live update on a running group of pods.

### Step Zero: Prerequisites

This example assumes that you have forked the repository and [turned up a Kubernetes cluster](https://github.com/GoogleCloudPlatform/kubernetes-new#contents):

```bash
$ cd kubernetes
$ hack/dev-build-and-up.sh
```

### Step One: Turn up the UX for the demo

You can use bash job control to run this in the background (note that you must use the default port -- 8001 -- for the following demonstration to work properly).  This can sometimes spew to the output so you could also run it in a different terminal.

```
$ ./cluster/kubectl.sh proxy --www=examples/update-demo/local/ &
+ ./cluster/kubectl.sh proxy --www=examples/update-demo/local/
I0218 15:18:31.623279   67480 proxy.go:36] Starting to serve on localhost:8001
```

Now visit the the [demo website](http://localhost:8001/static).  You won't see anything much quite yet.

### Step Two: Run the controller
Now we will turn up two replicas of an image.  They all serve on internal port 80.

```bash
$ ./cluster/kubectl.sh create -f examples/update-demo/v1beta1/nautilus-rc.yaml
```

After pulling the image from the Docker Hub to your worker nodes (which may take a minute or so) you'll see a couple of squares in the UI detailing the pods that are running along with the image that they are serving up.  A cute little nautilus.

### Step Three: Try resizing the controller

Now we will increase the number of replicas from two to four:

```bash
$ ./cluster/kubectl.sh resize rc update-demo-nautilus --replicas=4
```

If you go back to the [demo website](http://localhost:8001/static/index.html) you should eventually see four boxes, one for each pod.

### Step Four: Update the docker image
We will now update the docker image to serve a different image by doing a rolling update to a new Docker image.

```bash
$ ./cluster/kubectl.sh rolling-update update-demo-nautilus --update-period=10s -f examples/update-demo/v1beta1/kitten-rc.yaml
```
The rolling-update command in kubectl will do 2 things:

1. Create a new replication controller with a pod template that uses the new image (`gcr.io/google_containers/update-demo:kitten`)
2. Resize the old and new replication controllers until the new controller replaces the old. This will kill the current pods one at a time, spinnning up new ones to replace them.

Watch the [demo website](http://localhost:8001/static/index.html), it will update one pod every 10 seconds until all of the pods have the new image.

### Step Five: Bring down the pods

```bash
$ ./cluster/kubectl.sh stop rc update-demo-kitten
```

This will first 'stop' the replication controller by turning the target number of replicas to 0.  It'll then delete that controller.

### Step Six: Cleanup

To turn down a Kubernetes cluster:

```bash
$ cd ../..  # Up to kubernetes.
$ cluster/kube-down.sh
```

Kill the proxy running in the background:
After you are done running this demo make sure to kill it:

```bash
$ jobs
[1]+  Running                 ./cluster/kubectl.sh proxy --www=local/ &
$ kill %1
[1]+  Terminated: 15          ./cluster/kubectl.sh proxy --www=local/
```

### Updating the Docker images

If you want to build your own docker images, you can set `$DOCKER_HUB_USER` to your Docker user id and run the included shell script. It can take a few minutes to download/upload stuff.

```bash
$ export DOCKER_HUB_USER=my-docker-id
$ ./examples/update-demo/build-images.sh
```

To use your custom docker image in the above examples, you will need to change the image name in `examples/update-demo/v1beta1/nautilus-rc.yaml` and `examples/update-demo/v1beta1/kitten-rc.yaml`.

### Image Copyright

Note that the images included here are public domain.

* [kitten](http://commons.wikimedia.org/wiki/File:Kitten-stare.jpg)
* [nautilus](http://commons.wikimedia.org/wiki/File:Nautilus_pompilius.jpg)
