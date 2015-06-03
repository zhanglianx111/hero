## kubectl expose

Take a replicated application and expose it as Kubernetes Service

### Synopsis


Take a replicated application and expose it as Kubernetes Service.

Looks up a replication controller or service by name and uses the selector for that resource as the
selector for a new Service on the specified port.

```
kubectl expose RESOURCE NAME --port=port [--protocol=TCP|UDP] [--target-port=number-or-name] [--service-name=name] [--public-ip=ip] [--create-external-load-balancer=bool]
```

### Examples

```
// Creates a service for a replicated nginx, which serves on port 80 and connects to the containers on port 8000.
$ kubectl expose nginx --port=80 --target-port=8000

// Creates a second service based on the above service, exposing the container port 8443 as port 443 with the name "nginx-https"
$ kubectl expose service nginx --port=443 --target-port=8443 --service-name=nginx-https

// Create a service for a replicated streaming application on port 4100 balancing UDP traffic and named 'video-stream'.
$ kubectl expose streamer --port=4100 --protocol=udp --service-name=video-stream
```

### Options

```
      --container-port="": Synonym for --target-port
      --create-external-load-balancer=false: If true, create an external load balancer for this service. Implementation is cloud provider dependent. Default is 'false'.
      --dry-run=false: If true, only print the object that would be sent, without creating it.
      --generator="service/v1": The name of the API generator to use.  Default is 'service/v1'.
  -h, --help=false: help for expose
  -l, --labels="": Labels to apply to the service created by this call.
      --no-headers=false: When using the default output, don't print headers.
  -o, --output="": Output format. One of: json|yaml|template|templatefile.
      --output-version="": Output the formatted object with the given version (default api-version).
      --overrides="": An inline JSON override for the generated object. If this is non-empty, it is used to override the generated object. Requires that the object supply a valid apiVersion field.
      --port=-1: The port that the service should serve on. Required.
      --protocol="TCP": The network protocol for the service to be created. Default is 'tcp'.
      --public-ip="": Name of a public IP address to set for the service. The service will be assigned this IP in addition to its generated service IP.
      --selector="": A label selector to use for this service. If empty (the default) infer the selector from the replication controller.
      --service-name="": The name for the newly created service.
      --target-port="": Name or number for the port on the container that the service should direct traffic to. Optional.
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

