## kubectl stop

Gracefully shut down a resource by id or filename.

### Synopsis


Gracefully shut down a resource by id or filename.

Attempts to shut down and delete a resource that supports graceful termination.
If the resource is resizable it will be resized to 0 before deletion.

```
kubectl stop (-f FILENAME | RESOURCE (ID | -l label | --all))
```

### Examples

```
// Shut down foo.
$ kubectl stop replicationcontroller foo

// Stop pods and services with label name=myLabel.
$ kubectl stop pods,services -l name=myLabel

// Shut down the service defined in service.json
$ kubectl stop -f service.json

// Shut down all resources in the path/to/resources directory
$ kubectl stop -f path/to/resources
```

### Options

```
      --all=false: [-all] to select all the specified resources
  -f, --filename=[]: Filename, directory, or URL to file of resource(s) to be stopped
  -h, --help=false: help for stop
  -l, --selector="": Selector (label query) to filter on
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

