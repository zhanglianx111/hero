## kubectl rollingupdate

Perform a rolling update of the given ReplicationController.

### Synopsis


Perform a rolling update of the given ReplicationController.

Replaces the specified controller with new controller, updating one pod at a time to use the
new PodTemplate. The new-controller.json must specify the same namespace as the
existing controller and overwrite at least one (common) label in its replicaSelector.

```
kubectl rollingupdate OLD_CONTROLLER_NAME -f NEW_CONTROLLER_SPEC
```

### Examples

```
// Update pods of frontend-v1 using new controller data in frontend-v2.json.
$ kubectl rollingupdate frontend-v1 -f frontend-v2.json

// Update pods of frontend-v1 using JSON data passed into stdin.
$ cat frontend-v2.json | kubectl rollingupdate frontend-v1 -f -
```

### Options

```
  -f, --filename="": Filename or URL to file to use to create the new controller.
  -h, --help=false: help for rollingupdate
      --poll-interval="3s": Time delay between polling controller status after update. Valid time units are "ns", "us" (or "µs"), "ms", "s", "m", "h".
      --timeout="5m0s": Max time to wait for a controller to update before giving up. Valid time units are "ns", "us" (or "µs"), "ms", "s", "m", "h".
      --update-period="1m0s": Time to wait between updating pods. Valid time units are "ns", "us" (or "µs"), "ms", "s", "m", "h".
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

