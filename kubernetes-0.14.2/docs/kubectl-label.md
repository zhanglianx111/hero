## kubectl label

Update the labels on a resource

### Synopsis


Update the labels on a resource.

If --overwrite is true, then existing labels can be overwritten, otherwise attempting to overwrite a label will result in an error.
If --resource-version is specified, then updates will use this resource version, otherwise the existing resource-version will be used.

```
kubectl label [--overwrite] RESOURCE NAME KEY_1=VAL_1 ... KEY_N=VAL_N [--resource-version=version]
```

### Examples

```
// Update pod 'foo' with the label 'unhealthy' and the value 'true'.
$ kubectl label pods foo unhealthy=true

// Update pod 'foo' with the label 'status' and the value 'unhealthy', overwriting any existing value.
$ kubectl label --overwrite pods foo status=unhealthy

// Update all pods in the namespace
$ kubectl label pods --all status=unhealthy

// Update pod 'foo' only if the resource is unchanged from version 1.
$ kubectl label pods foo status=unhealthy --resource-version=1

// Update pod 'foo' by removing a label named 'bar' if it exists.
// Does not require the --overwrite flag.
$ kubectl label pods foo bar-
```

### Options

```
      --all=false: select all resources in the namespace of the specified resource types
  -h, --help=false: help for label
      --no-headers=false: When using the default output, don't print headers.
  -o, --output="": Output format. One of: json|yaml|template|templatefile.
      --output-version="": Output the formatted object with the given version (default api-version).
      --overwrite=false: If true, allow labels to be overwritten, otherwise reject label updates that overwrite existing labels.
      --resource-version="": If non-empty, the labels update will only succeed if this is the current resource-version for the object. Only valid when specifying a single resource.
  -l, --selector="": Selector (label query) to filter on
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

