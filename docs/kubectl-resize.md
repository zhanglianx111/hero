## kubectl resize

Set a new size for a Replication Controller.

### Synopsis


Set a new size for a Replication Controller.

Resize also allows users to specify one or more preconditions for the resize action.
If --current-replicas or --resource-version is specified, it is validated before the
resize is attempted, and it is guaranteed that the precondition holds true when the
resize is sent to the server.

```
kubectl resize [--resource-version=version] [--current-replicas=count] --replicas=COUNT RESOURCE ID
```

### Examples

```
// Resize replication controller named 'foo' to 3.
$ kubectl resize --replicas=3 replicationcontrollers foo

// If the replication controller named foo's current size is 2, resize foo to 3.
$ kubectl resize --current-replicas=2 --replicas=3 replicationcontrollers foo
```

### Options

```
      --current-replicas=-1: Precondition for current size. Requires that the current size of the replication controller match this value in order to resize.
  -h, --help=false: help for resize
      --replicas=-1: The new desired number of replicas. Required.
      --resource-version="": Precondition for resource version. Requires that the current resource version match this value in order to resize.
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

