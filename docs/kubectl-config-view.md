## kubectl config view

displays merged .kubeconfig settings or a specified .kubeconfig file.

### Synopsis


displays merged .kubeconfig settings or a specified .kubeconfig file.

You can use --output=template --template=TEMPLATE to extract specific values.

```
kubectl config view
```

### Examples

```
// Show merged .kubeconfig settings.
$ kubectl config view

// Show only local ./.kubeconfig settings
$ kubectl config view --local

// Get the password for the e2e user
$ kubectl config view -o template --template='{{ index . "users" "e2e" "password" }}'
```

### Options

```
  -h, --help=false: help for view
      --merge=true: merge together the full hierarchy of .kubeconfig files
      --no-headers=false: When using the default output, don't print headers.
  -o, --output="": Output format. One of: json|yaml|template|templatefile.
      --output-version="": Output the formatted object with the given version (default api-version).
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
      --envvar=false: use the .kubeconfig from $KUBECONFIG
      --global=false: use the .kubeconfig from /home/username
      --insecure-skip-tls-verify=false: If true, the server's certificate will not be checked for validity. This will make your HTTPS connections insecure.
      --kubeconfig="": use a particular .kubeconfig file
      --local=false: use the .kubeconfig in the current directory
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
* [kubectl-config](kubectl-config.md)

