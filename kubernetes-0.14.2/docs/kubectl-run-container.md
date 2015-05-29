## kubectl run-container

Run a particular image on the cluster.

### Synopsis


Create and run a particular image, possibly replicated.
Creates a replication controller to manage the created container(s).

```
kubectl run-container NAME --image=image [--port=port] [--replicas=replicas] [--dry-run=bool] [--overrides=inline-json]
```

### Examples

```
// Starts a single instance of nginx.
$ kubectl run-container nginx --image=dockerfile/nginx

// Starts a replicated instance of nginx.
$ kubectl run-container nginx --image=dockerfile/nginx --replicas=5

// Dry run. Print the corresponding API objects without creating them.
$ kubectl run-container nginx --image=dockerfile/nginx --dry-run

// Start a single instance of nginx, but overload the desired state with a partial set of values parsed from JSON.
$ kubectl run-container nginx --image=dockerfile/nginx --overrides='{ "apiVersion": "v1beta1", "desiredState": { ... } }'
```

### Options

```
      --dry-run=false: If true, only print the object that would be sent, without sending it.
      --generator="run-container/v1": The name of the API generator to use.  Default is 'run-container-controller/v1'.
  -h, --help=false: help for run-container
      --image="": The image for the container to run.
  -l, --labels="": Labels to apply to the pod(s) created by this call to run-container.
      --no-headers=false: When using the default output, don't print headers.
  -o, --output="": Output format. One of: json|yaml|template|templatefile.
      --output-version="": Output the formatted object with the given version (default api-version).
      --overrides="": An inline JSON override for the generated object. If this is non-empty, it is used to override the generated object. Requires that the object supply a valid apiVersion field.
      --port=-1: The port that this container exposes.
  -r, --replicas=1: Number of replicas to create for this container. Default is 1.
  -t, --template="": Template string or path to template file to use when -o=template or -o=templatefile.  The template format is golang templates [http://golang.org/pkg/text/template/#pkg-overview]
```

### Options inherrited from parent commands

```
      --alsologtostderr=false: log to standard error as well as files
      --api-version="": The API version to use when talking to the server
  -a, --auth-path="": Path to the auth info file. If missing, prompt the user. Only used if using https.
      --certificate-authority="": Path to a cert. file for the certificate authority.
      --client-certificate="": Path to a client key file for TLS.
      --client-key="": Path to a client key file for TLS.
      --cluster="": The name of the kubeconfig cluster to use
      --context="": The name of the kubeconfig context to use
      --insecure-skip-tls-verify=false: If true, the server's certificate will not be checked for validity. This will make your HTTPS connections insecure.
      --kubeconfig="": Path to the kubeconfig file to use for CLI requests.
      --log_backtrace_at=:0: when logging hits line file:N, emit a stack trace
      --log_dir=: If non-empty, write log files in this directory
      --log_flush_frequency=5s: Maximum number of seconds between log flushes
      --logtostderr=true: log to standard error instead of files
      --match-server-version=false: Require server version to match client version
      --namespace="": If present, the namespace scope for this CLI request.
      --password="": Password for basic authentication to the API server.
  -s, --server="": The address and port of the Kubernetes API server
      --stderrthreshold=2: logs at or above this threshold go to stderr
      --token="": Bearer token for authentication to the API server.
      --user="": The name of the kubeconfig user to use
      --username="": Username for basic authentication to the API server.
      --v=0: log level for V logs
      --validate=false: If true, use a schema to validate the input before sending it
      --vmodule=: comma-separated list of pattern=N settings for file-filtered logging
```

### SEE ALSO
* [kubectl](kubectl.md)

