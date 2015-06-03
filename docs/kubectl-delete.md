## kubectl delete

Delete a resource by filename, stdin, or resource and ID.

### Synopsis


Delete a resource by filename, stdin, resource and ID, or by resources and label selector.

JSON and YAML formats are accepted.

If both a filename and command line arguments are passed, the command line
arguments are used and the filename is ignored.

Note that the delete command does NOT do resource version checks, so if someone
submits an update to a resource right when you submit a delete, their update
will be lost along with the rest of the resource.

```
kubectl delete ([-f FILENAME] | (RESOURCE [(ID | -l label | --all)]
```

### Examples

```
// Delete a pod using the type and ID specified in pod.json.
$ kubectl delete -f pod.json

// Delete a pod based on the type and ID in the JSON passed into stdin.
$ cat pod.json | kubectl delete -f -

// Delete pods and services with label name=myLabel.
$ kubectl delete pods,services -l name=myLabel

// Delete a pod with ID 1234-56-7890-234234-456456.
$ kubectl delete pod 1234-56-7890-234234-456456

// Delete all pods
$ kubectl delete pods --all
```

### Options

```
      --all=false: [-all] to select all the specified resources
  -f, --filename=[]: Filename, directory, or URL to a file containing the resource to delete
  -h, --help=false: help for delete
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

