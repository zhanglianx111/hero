#!/bin/bash

# Copyright 2014 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# A library of helper functions and constant for the local config.

# Use the config file specified in $KUBE_CONFIG_FILE, or default to
# config-default.sh.
KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..
source "${KUBE_ROOT}/cluster/gce/${KUBE_CONFIG_FILE-"config-default.sh"}"
source "${KUBE_ROOT}/cluster/common.sh"

NODE_INSTANCE_PREFIX="${INSTANCE_PREFIX}-minion"

KUBE_PROMPT_FOR_UPDATE=y

# Verify prereqs
function verify-prereqs {
  local cmd
  for cmd in gcloud gsutil; do
    if ! which "${cmd}" >/dev/null; then
      echo "Can't find ${cmd} in PATH.  Do you wish to install the Google Cloud SDK? [Y/n]"
      local resp
      read resp
      if [[ "${resp}" != "n" && "${resp}" != "N" ]]; then
        curl https://sdk.cloud.google.com | bash
      fi
      if ! which "${cmd}" >/dev/null; then
        echo "Can't find ${cmd} in PATH, please fix and retry. The Google Cloud "
        echo "SDK can be downloaded from https://cloud.google.com/sdk/."
        exit 1
      fi
    fi 
  done
  # update and install components as needed
  if [[ "${KUBE_PROMPT_FOR_UPDATE}" != "y" ]]; then
    gcloud_prompt="-q"
  fi
  gcloud ${gcloud_prompt:-} components update preview || true
  gcloud ${gcloud_prompt:-} components update || true
}

# Create a temp dir that'll be deleted at the end of this bash session.
#
# Vars set:
#   KUBE_TEMP
function ensure-temp-dir {
  if [[ -z ${KUBE_TEMP-} ]]; then
    KUBE_TEMP=$(mktemp -d -t kubernetes.XXXXXX)
    trap 'rm -rf "${KUBE_TEMP}"' EXIT
  fi
}

# Verify and find the various tar files that we are going to use on the server.
#
# Vars set:
#   SERVER_BINARY_TAR
#   SALT_TAR
function find-release-tars {
  SERVER_BINARY_TAR="${KUBE_ROOT}/server/kubernetes-server-linux-amd64.tar.gz"
  if [[ ! -f "$SERVER_BINARY_TAR" ]]; then
    SERVER_BINARY_TAR="${KUBE_ROOT}/_output/release-tars/kubernetes-server-linux-amd64.tar.gz"
  fi
  if [[ ! -f "$SERVER_BINARY_TAR" ]]; then
    echo "!!! Cannot find kubernetes-server-linux-amd64.tar.gz"
    exit 1
  fi

  SALT_TAR="${KUBE_ROOT}/server/kubernetes-salt.tar.gz"
  if [[ ! -f "$SALT_TAR" ]]; then
    SALT_TAR="${KUBE_ROOT}/_output/release-tars/kubernetes-salt.tar.gz"
  fi
  if [[ ! -f "$SALT_TAR" ]]; then
    echo "!!! Cannot find kubernetes-salt.tar.gz"
    exit 1
  fi
}

# Use the gcloud defaults to find the project.  If it is already set in the
# environment then go with that.
#
# Vars set:
#   PROJECT
#   PROJECT_REPORTED
function detect-project () {
  if [[ -z "${PROJECT-}" ]]; then
    PROJECT=$(gcloud config list project | tail -n 1 | cut -f 3 -d ' ')
  fi

  if [[ -z "${PROJECT-}" ]]; then
    echo "Could not detect Google Cloud Platform project.  Set the default project using " >&2
    echo "'gcloud config set project <PROJECT>'" >&2
    exit 1
  fi
  if [[ -z "${PROJECT_REPORTED-}" ]]; then
    echo "Project: ${PROJECT}" >&2
    echo "Zone: ${ZONE}" >&2
    PROJECT_REPORTED=true
  fi
}


# Take the local tar files and upload them to Google Storage.  They will then be
# downloaded by the master as part of the start up script for the master.
#
# Assumed vars:
#   PROJECT
#   SERVER_BINARY_TAR
#   SALT_TAR
# Vars set:
#   SERVER_BINARY_TAR_URL
#   SALT_TAR_URL
function upload-server-tars() {
  SERVER_BINARY_TAR_URL=
  SALT_TAR_URL=

  local project_hash
  if which md5 > /dev/null 2>&1; then
    project_hash=$(md5 -q -s "$PROJECT")
  else
    project_hash=$(echo -n "$PROJECT" | md5sum | awk '{ print $1 }')
  fi
  project_hash=${project_hash:0:5}

  local -r staging_bucket="gs://kubernetes-staging-${project_hash}"

  # Ensure the bucket is created
  if ! gsutil ls "$staging_bucket" > /dev/null 2>&1 ; then
    echo "Creating $staging_bucket"
    gsutil mb "${staging_bucket}"
  fi

  local -r staging_path="${staging_bucket}/devel"

  echo "+++ Staging server tars to Google Storage: ${staging_path}"
  local server_binary_gs_url="${staging_path}/${SERVER_BINARY_TAR##*/}"
  gsutil -q -h "Cache-Control:private, max-age=0" cp "${SERVER_BINARY_TAR}" "${server_binary_gs_url}"
  gsutil acl ch -g all:R "${server_binary_gs_url}" >/dev/null 2>&1
  local salt_gs_url="${staging_path}/${SALT_TAR##*/}"
  gsutil -q -h "Cache-Control:private, max-age=0" cp "${SALT_TAR}" "${salt_gs_url}"
  gsutil acl ch -g all:R "${salt_gs_url}" >/dev/null 2>&1

  # Convert from gs:// URL to an https:// URL
  SERVER_BINARY_TAR_URL="${server_binary_gs_url/gs:\/\//https://storage.googleapis.com/}"
  SALT_TAR_URL="${salt_gs_url/gs:\/\//https://storage.googleapis.com/}"
}

# Detect minions created in the minion group
#
# Assumed vars:
#   NODE_INSTANCE_PREFIX
# Vars set:
#   MINION_NAMES
function detect-minion-names {
  detect-project
  MINION_NAMES=($(gcloud preview --project "${PROJECT}" instance-groups \
    --zone "${ZONE}" instances --group "${NODE_INSTANCE_PREFIX}-group" list \
    | cut -d'/' -f11))
  echo "MINION_NAMES=${MINION_NAMES[*]}"
}

# Waits until the number of running nodes in the instance group is equal to NUM_NODES
#
# Assumed vars:
#   NODE_INSTANCE_PREFIX
#   NUM_MINIONS
function wait-for-minions-to-run {
  detect-project
  local running_minions=0
  while [[ "${NUM_MINIONS}" != "${running_minions}" ]]; do
    echo -e -n "${color_yellow}Waiting for minions to run. "
    echo -e "${running_minions} out of ${NUM_MINIONS} running. Retrying.${color_norm}"
    sleep 5
    running_minions=$(gcloud preview --project "${PROJECT}" instance-groups \
      --zone "${ZONE}" instances --group "${NODE_INSTANCE_PREFIX}-group" list \
      --running | wc -l | xargs)
  done
}

# Detect the information about the minions
#
# Assumed vars:
#   ZONE
# Vars set:
#   MINION_NAMES
#   KUBE_MINION_IP_ADDRESSES (array)
function detect-minions () {
  detect-project
  detect-minion-names
  KUBE_MINION_IP_ADDRESSES=()
  for (( i=0; i<${#MINION_NAMES[@]}; i++)); do
    local minion_ip=$(gcloud compute instances describe --project "${PROJECT}" --zone "${ZONE}" \
      "${MINION_NAMES[$i]}" --fields networkInterfaces[0].accessConfigs[0].natIP \
      --format=text | awk '{ print $2 }')
    if [[ -z "${minion_ip-}" ]] ; then
      echo "Did not find ${MINION_NAMES[$i]}" >&2
    else
      echo "Found ${MINION_NAMES[$i]} at ${minion_ip}"
      KUBE_MINION_IP_ADDRESSES+=("${minion_ip}")
    fi
  done
  if [[ -z "${KUBE_MINION_IP_ADDRESSES-}" ]]; then
    echo "Could not detect Kubernetes minion nodes.  Make sure you've launched a cluster with 'kube-up.sh'" >&2
    exit 1
  fi
}

# Detect the IP for the master
#
# Assumed vars:
#   MASTER_NAME
#   ZONE
# Vars set:
#   KUBE_MASTER
#   KUBE_MASTER_IP
#   KUBE_MASTER_IP_INTERNAL
function detect-master () {
  detect-project
  KUBE_MASTER=${MASTER_NAME}
  if [[ -z "${KUBE_MASTER_IP-}" ]]; then
    KUBE_MASTER_IP=$(gcloud compute instances describe --project "${PROJECT}" --zone "${ZONE}" \
      "${MASTER_NAME}" --fields networkInterfaces[0].accessConfigs[0].natIP \
      --format=text | awk '{ print $2 }')
  fi
  if [[ -z "${KUBE_MASTER_IP-}" ]]; then
    echo "Could not detect Kubernetes master node.  Make sure you've launched a cluster with 'kube-up.sh'" >&2
    exit 1
  fi
  echo "Using master: $KUBE_MASTER (external IP: $KUBE_MASTER_IP)"
}

# Ensure that we have a password created for validating to the master.  Will
# read from kubeconfig for the current context if available.
#
# Assumed vars
#   KUBE_ROOT
#
# Vars set:
#   KUBE_USER
#   KUBE_PASSWORD
function get-password {
  get-kubeconfig-basicauth
  if [[ -z "${KUBE_USER}" || -z "${KUBE_PASSWORD}" ]]; then
    KUBE_USER=admin
    KUBE_PASSWORD=$(python -c 'import string,random; print "".join(random.SystemRandom().choice(string.ascii_letters + string.digits) for _ in range(16))')
  fi
}

# Set MASTER_HTPASSWD
function set-master-htpasswd {
  python "${KUBE_ROOT}/third_party/htpasswd/htpasswd.py" \
    -b -c "${KUBE_TEMP}/htpasswd" "$KUBE_USER" "$KUBE_PASSWORD"
  local htpasswd
  MASTER_HTPASSWD=$(cat "${KUBE_TEMP}/htpasswd")
}

# Generate authentication token for admin user. Will
# read from $HOME/.kubernetes_auth if available.
#
# Vars set:
#   KUBE_ADMIN_TOKEN
function get-admin-token {
  local file="$HOME/.kubernetes_auth"
  if [[ -r "$file" ]]; then
    KUBE_ADMIN_TOKEN=$(cat "$file" | python -c 'import json,sys;print json.load(sys.stdin)["BearerToken"]')
    return
  fi
  KUBE_ADMIN_TOKEN=$(python -c 'import string,random; print "".join(random.SystemRandom().choice(string.ascii_letters + string.digits) for _ in range(32))')
}



# Wait for background jobs to finish. Exit with
# an error status if any of the jobs failed.
function wait-for-jobs {
  local fail=0
  local job
  for job in $(jobs -p); do
    wait "${job}" || fail=$((fail + 1))
  done
  if (( fail != 0 )); then
    echo -e "${color_red}${fail} commands failed.  Exiting.${color_norm}" >&2
    # Ignore failures for now.
    # exit 2
  fi
}

# Robustly try to create a firewall rule.
# $1: The name of firewall rule.
# $2: IP ranges.
# $3: Target tags for this firewall rule.
function create-firewall-rule {
  detect-project
  local attempt=0
  while true; do
    if ! gcloud compute firewall-rules create "$1" \
      --project "${PROJECT}" \
      --network "${NETWORK}" \
      --source-ranges "$2" \
      --target-tags "$3" \
      --allow tcp udp icmp esp ah sctp; then
        if (( attempt > 5 )); then
          echo -e "${color_red}Failed to create firewall rule $1 ${color_norm}"
          exit 2
        fi
        echo -e "${color_yellow}Attempt $(($attempt+1)) failed to create firewall rule $1. Retrying.${color_norm}"
        attempt=$(($attempt+1))
    else
        break
    fi
  done
}

# Robustly try to create a route.
# $1: The name of the route.
# $2: IP range.
function create-route {
  detect-project
  local attempt=0
  while true; do
    if ! gcloud compute routes create "$1" \
      --project "${PROJECT}" \
      --destination-range "$2" \
      --network "${NETWORK}" \
      --next-hop-instance "$1" \
      --next-hop-instance-zone "${ZONE}"; then
        if (( attempt > 5 )); then
          echo -e "${color_red}Failed to create route $1 ${color_norm}"
          exit 2
        fi
        echo -e "${color_yellow}Attempt $(($attempt+1)) failed to create route $1. Retrying.${color_norm}"
        attempt=$(($attempt+1))
    else
        break
    fi
  done
}

# Robustly try to create an instance template.
# $1: The name of the instance template.
# $2: The scopes flag.
# $3: The minion start script metadata from file.
# $4: The kube-env metadata.
# $5: Raw metadata
function create-node-template {
  detect-project
  local attempt=0
  while true; do
    if ! gcloud compute instance-templates create "$1" \
      --project "${PROJECT}" \
      --machine-type "${MINION_SIZE}" \
      --boot-disk-type "${MINION_DISK_TYPE}" \
      --boot-disk-size "${MINION_DISK_SIZE}" \
      --image-project="${IMAGE_PROJECT}" \
      --image "${IMAGE}" \
      --tags "${MINION_TAG}" \
      --network "${NETWORK}" \
      $2 \
      --can-ip-forward \
      --metadata-from-file "$3" "$4" \
      --metadata "$5"; then
        if (( attempt > 5 )); then
          echo -e "${color_red}Failed to create instance template $1 ${color_norm}"
          exit 2
        fi
        echo -e "${color_yellow}Attempt $(($attempt+1)) failed to create instance template $1. Retrying.${color_norm}"
        attempt=$(($attempt+1))
    else
        break
    fi
  done
}

# Robustly try to add metadata on an instance.
# $1: The name of the instace.
# $2: The metadata key=value pair to add.
function add-instance-metadata {
  detect-project
  local attempt=0
  while true; do
    if ! gcloud compute instances add-metadata "$1" \
      --project "${PROJECT}" \
      --zone "${ZONE}" \
      --metadata "$2"; then
        if (( attempt > 5 )); then
          echo -e "${color_red}Failed to add instance metadata in $1 ${color_norm}"
          exit 2
        fi
        echo -e "${color_yellow}Attempt $(($attempt+1)) failed to add metadata in $1. Retrying.${color_norm}"
        attempt=$(($attempt+1))
    else
        break
    fi
  done
}

# Robustly try to add metadata on an instance, from a file.
# $1: The name of the instace.
# $2: The metadata key=file pair to add.
function add-instance-metadata-from-file {
  detect-project
  local attempt=0
  while true; do
    if ! gcloud compute instances add-metadata "$1" \
      --project "${PROJECT}" \
      --zone "${ZONE}" \
      --metadata-from-file "$2"; then
        if (( attempt > 5 )); then
          echo -e "${color_red}Failed to add instance metadata in $1 ${color_norm}"
          exit 2
        fi
        echo -e "${color_yellow}Attempt $(($attempt+1)) failed to add metadata in $1. Retrying.${color_norm}"
        attempt=$(($attempt+1))
    else
        break
    fi
  done
}

# Quote something appropriate for a yaml string.
#
# TODO(zmerlynn): Note that this function doesn't so much "quote" as
# "strip out quotes", and we really should be using a YAML library for
# this, but PyYAML isn't shipped by default, and *rant rant rant ... SIGH*
function yaml-quote {
  echo "'$(echo "${@}" | sed -e "s/'/''/g")'"
}

# $1: if 'true', we're building a master yaml, else a node
function build-kube-env {
  local master=$1
  local file=$2

  rm -f ${file}
  cat >$file <<EOF
ENV_TIMESTAMP: $(yaml-quote $(date -u +%Y-%m-%dT%T%z))
INSTANCE_PREFIX: $(yaml-quote ${INSTANCE_PREFIX})
NODE_INSTANCE_PREFIX: $(yaml-quote ${NODE_INSTANCE_PREFIX})
SERVER_BINARY_TAR_URL: $(yaml-quote ${SERVER_BINARY_TAR_URL})
SALT_TAR_URL: $(yaml-quote ${SALT_TAR_URL})
PORTAL_NET: $(yaml-quote ${PORTAL_NET})
ENABLE_CLUSTER_MONITORING: $(yaml-quote ${ENABLE_CLUSTER_MONITORING:-false})
ENABLE_NODE_MONITORING: $(yaml-quote ${ENABLE_NODE_MONITORING:-false})
ENABLE_CLUSTER_LOGGING: $(yaml-quote ${ENABLE_CLUSTER_LOGGING:-false})
ENABLE_NODE_LOGGING: $(yaml-quote ${ENABLE_NODE_LOGGING:-false})
LOGGING_DESTINATION: $(yaml-quote ${LOGGING_DESTINATION:-})
ELASTICSEARCH_LOGGING_REPLICAS: $(yaml-quote ${ELASTICSEARCH_LOGGING_REPLICAS:-})
ENABLE_CLUSTER_DNS: $(yaml-quote ${ENABLE_CLUSTER_DNS:-false})
DNS_REPLICAS: $(yaml-quote ${DNS_REPLICAS:-})
DNS_SERVER_IP: $(yaml-quote ${DNS_SERVER_IP:-})
DNS_DOMAIN: $(yaml-quote ${DNS_DOMAIN:-})
MASTER_HTPASSWD: $(yaml-quote ${MASTER_HTPASSWD})
ADMISSION_CONTROL: $(yaml-quote ${ADMISSION_CONTROL:-})
MASTER_IP_RANGE: $(yaml-quote ${MASTER_IP_RANGE})
EOF

  if [[ "${master}" != "true" ]]; then
    cat >>$file <<EOF
KUBERNETES_MASTER_NAME: $(yaml-quote ${MASTER_NAME})
ZONE: $(yaml-quote ${ZONE})
EXTRA_DOCKER_OPTS: $(yaml-quote ${EXTRA_DOCKER_OPTS})
ENABLE_DOCKER_REGISTRY_CACHE: $(yaml-quote ${ENABLE_DOCKER_REGISTRY_CACHE:-false})
EOF
  fi
}

function write-master-env {
  build-kube-env true "${KUBE_TEMP}/master-kube-env.yaml"
}

function write-node-env {
  build-kube-env false "${KUBE_TEMP}/node-kube-env.yaml"
}

# Instantiate a kubernetes cluster
#
# Assumed vars
#   KUBE_ROOT
#   <Various vars set in config file>
function kube-up {
  ensure-temp-dir
  detect-project

  get-password
  set-master-htpasswd

  # Make sure we have the tar files staged on Google Storage
  find-release-tars
  upload-server-tars

  if ! gcloud compute networks --project "${PROJECT}" describe "${NETWORK}" &>/dev/null; then
    echo "Creating new network: ${NETWORK}"
    # The network needs to be created synchronously or we have a race. The
    # firewalls can be added concurrent with instance creation.
    gcloud compute networks create --project "${PROJECT}" "${NETWORK}" --range "10.240.0.0/16"
  fi

  if ! gcloud compute firewall-rules --project "${PROJECT}" describe "${NETWORK}-default-internal" &>/dev/null; then
    gcloud compute firewall-rules create "${NETWORK}-default-internal" \
      --project "${PROJECT}" \
      --network "${NETWORK}" \
      --source-ranges "10.0.0.0/8" \
      --allow "tcp:1-65535" "udp:1-65535" "icmp" &
  fi

  if ! gcloud compute firewall-rules describe --project "${PROJECT}" "${NETWORK}-default-ssh" &>/dev/null; then
    gcloud compute firewall-rules create "${NETWORK}-default-ssh" \
      --project "${PROJECT}" \
      --network "${NETWORK}" \
      --source-ranges "0.0.0.0/0" \
      --allow "tcp:22" &
  fi

  echo "Starting master and configuring firewalls"
  gcloud compute firewall-rules create "${MASTER_NAME}-https" \
    --project "${PROJECT}" \
    --network "${NETWORK}" \
    --target-tags "${MASTER_TAG}" \
    --allow tcp:443 &

  # We have to make sure the disk is created before creating the master VM, so
  # run this in the foreground.
  gcloud compute disks create "${MASTER_NAME}-pd" \
    --project "${PROJECT}" \
    --zone "${ZONE}" \
    --size "10GB"

  # Generate a bearer token for this cluster. We push this separately
  # from the other cluster variables so that the client (this
  # computer) can forget it later. This should disappear with
  # https://github.com/GoogleCloudPlatform/kubernetes/issues/3168
  KUBELET_TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)

  write-master-env
  gcloud compute instances create "${MASTER_NAME}" \
    --project "${PROJECT}" \
    --zone "${ZONE}" \
    --machine-type "${MASTER_SIZE}" \
    --image-project="${IMAGE_PROJECT}" \
    --image "${IMAGE}" \
    --tags "${MASTER_TAG}" \
    --network "${NETWORK}" \
    --scopes "storage-ro" "compute-rw" \
    --can-ip-forward \
    --metadata-from-file \
      "startup-script=${KUBE_ROOT}/cluster/gce/configure-vm.sh" \
      "kube-env=${KUBE_TEMP}/master-kube-env.yaml" \
    --disk name="${MASTER_NAME}-pd" device-name=master-pd mode=rw boot=no auto-delete=no &

  # Create a single firewall rule for all minions.
  create-firewall-rule "${MINION_TAG}-all" "${CLUSTER_IP_RANGE}" "${MINION_TAG}" &

  # Report logging choice (if any).
  if [[ "${ENABLE_NODE_LOGGING-}" == "true" ]]; then
    echo "+++ Logging using Fluentd to ${LOGGING_DESTINATION:-unknown}"
    # For logging to GCP we need to enable some minion scopes.
    if [[ "${LOGGING_DESTINATION-}" == "gcp" ]]; then
      MINION_SCOPES+=('https://www.googleapis.com/auth/logging.write')
    fi
  fi

  # Wait for last batch of jobs
  wait-for-jobs
  add-instance-metadata "${MASTER_NAME}" "kube-token=${KUBELET_TOKEN}"

  echo "Creating minions."

  local -a scope_flags=()
  if (( "${#MINION_SCOPES[@]}" > 0 )); then
    scope_flags=("--scopes" "${MINION_SCOPES[@]}")
  else
    scope_flags=("--no-scopes")
  fi

  write-node-env
  create-node-template "${NODE_INSTANCE_PREFIX}-template" "${scope_flags[*]}" \
    "startup-script=${KUBE_ROOT}/cluster/gce/configure-vm.sh" \
    "kube-env=${KUBE_TEMP}/node-kube-env.yaml" \
    "kube-token=${KUBELET_TOKEN}"

  gcloud preview managed-instance-groups --zone "${ZONE}" \
      create "${NODE_INSTANCE_PREFIX}-group" \
      --project "${PROJECT}" \
      --base-instance-name "${NODE_INSTANCE_PREFIX}" \
      --size "${NUM_MINIONS}" \
      --template "${NODE_INSTANCE_PREFIX}-template" || true;
  # TODO: this should be true when the above create managed-instance-group
  # command returns, but currently it returns before the instances come up due
  # to gcloud's deficiency.
  wait-for-minions-to-run
  detect-minion-names

  # Create the routes and set IP ranges to instance metadata, 5 instances at a time.
  for (( i=0; i<${#MINION_NAMES[@]}; i++)); do
    create-route "${MINION_NAMES[$i]}" "${MINION_IP_RANGES[$i]}" &
    add-instance-metadata "${MINION_NAMES[$i]}" "node-ip-range=${MINION_IP_RANGES[$i]}" &

    if [ $i -ne 0 ] && [ $((i%5)) -eq 0 ]; then
      echo Waiting for a batch of routes at $i...
      wait-for-jobs
    fi

  done
  create-route "${MASTER_NAME}" "${MASTER_IP_RANGE}"

  # Wait for last batch of jobs.
  wait-for-jobs

  detect-master

  # Reserve the master's IP so that it can later be transferred to another VM
  # without disrupting the kubelets. IPs are associated with regions, not zones,
  # so extract the region name, which is the same as the zone but with the final
  # dash and characters trailing the dash removed.
  local REGION=${ZONE%-*}
  gcloud compute addresses create "${MASTER_NAME}-ip" \
    --project "${PROJECT}" \
    --addresses "${KUBE_MASTER_IP}" \
    --region "${REGION}"

  echo "Waiting for cluster initialization."
  echo
  echo "  This will continually check to see if the API for kubernetes is reachable."
  echo "  This might loop forever if there was some uncaught error during start"
  echo "  up."
  echo

  until curl --insecure --user "${KUBE_USER}:${KUBE_PASSWORD}" --max-time 5 \
          --fail --output /dev/null --silent "https://${KUBE_MASTER_IP}/api/v1beta1/pods"; do
      printf "."
      sleep 2
  done

  echo "Kubernetes cluster created."

  # TODO use token instead of basic auth
  export KUBECONFIG="${HOME}/.kube/.kubeconfig"
  export KUBE_CERT="/tmp/kubecfg.crt"
  export KUBE_KEY="/tmp/kubecfg.key"
  export CA_CERT="/tmp/kubernetes.ca.crt"
  export CONTEXT="${PROJECT}_${INSTANCE_PREFIX}"

  # TODO: generate ADMIN (and KUBELET) tokens and put those in the master's
  # config file.  Distribute the same way the htpasswd is done.
  (
   umask 077
   gcloud compute ssh --project "${PROJECT}" --zone "$ZONE" "${MASTER_NAME}" --command "sudo cat /srv/kubernetes/kubecfg.crt" >"${KUBE_CERT}" 2>/dev/null
   gcloud compute ssh --project "${PROJECT}" --zone "$ZONE" "${MASTER_NAME}" --command "sudo cat /srv/kubernetes/kubecfg.key" >"${KUBE_KEY}" 2>/dev/null
   gcloud compute ssh --project "${PROJECT}" --zone "$ZONE" "${MASTER_NAME}" --command "sudo cat /srv/kubernetes/ca.crt" >"${CA_CERT}" 2>/dev/null

   create-kubeconfig
  )

  echo "Sanity checking cluster..."

  # Basic sanity checking
  local i
  local rc # Capture return code without exiting because of errexit bash option
  for (( i=0; i<${#MINION_NAMES[@]}; i++)); do
      # Make sure docker is installed and working.
      local attempt=0
      while true; do
        echo -n Attempt "$(($attempt+1))" to check Docker on node "${MINION_NAMES[$i]}" ...
        local output=$(gcloud compute --project "${PROJECT}" ssh --zone "$ZONE" "${MINION_NAMES[$i]}" --command "sudo docker ps -a" 2>/dev/null)
        if [[ -z "${output}" ]]; then
          if (( attempt > 9 )); then
            echo
            echo -e "${color_red}Docker failed to install on node ${MINION_NAMES[$i]}. Your cluster is unlikely" >&2
            echo "to work correctly. Please run ./cluster/kube-down.sh and re-create the" >&2
            echo -e "cluster. (sorry!)${color_norm}" >&2
            exit 1
          fi
        elif [[ "${output}" != *"kubernetes/pause"* ]]; then
          if (( attempt > 9 )); then
            echo
            echo -e "${color_red}Failed to observe kubernetes/pause on node ${MINION_NAMES[$i]}. Your cluster is unlikely" >&2
            echo "to work correctly. Please run ./cluster/kube-down.sh and re-create the" >&2
            echo -e "cluster. (sorry!)${color_norm}" >&2
            exit 1
          fi
        else
          echo -e " ${color_green}[working]${color_norm}"
          break
        fi
        echo -e " ${color_yellow}[not working yet]${color_norm}"
        # Start Docker, in case it failed to start.
        gcloud compute --project "${PROJECT}" ssh --zone "$ZONE" "${MINION_NAMES[$i]}" \
                       --command "sudo service docker start" 2>/dev/null || true
        attempt=$(($attempt+1))
        sleep 30
      done
  done

  echo
  echo -e "${color_green}Kubernetes cluster is running.  The master is running at:"
  echo
  echo -e "${color_yellow}  https://${KUBE_MASTER_IP}"
  echo
  echo -e "${color_green}The user name and password to use is located in ${KUBECONFIG}.${color_norm}"
  echo

}

# Delete a kubernetes cluster. This is called from test-teardown.
#
# Assumed vars:
#   MASTER_NAME
#   NODE_INSTANCE_PREFIX
#   ZONE
# This function tears down cluster resources 10 at a time to avoid issuing too many
# API calls and exceeding API quota. It is important to bring down the instances before bringing
# down the firewall rules and routes.
function kube-down {
  detect-project

  echo "Bringing down cluster"

  gcloud preview managed-instance-groups --zone "${ZONE}" delete \
    --project "${PROJECT}" \
    --quiet \
    "${NODE_INSTANCE_PREFIX}-group" || true

  gcloud compute instance-templates delete \
    --project "${PROJECT}" \
    --quiet \
    "${NODE_INSTANCE_PREFIX}-template" || true

  # First delete the master (if it exists).
  gcloud compute instances delete \
    --project "${PROJECT}" \
    --quiet \
    --delete-disks all \
    --zone "${ZONE}" \
    "${MASTER_NAME}" || true

  # Delete the master pd (possibly leaked by kube-up if master create failed)
  gcloud compute disks delete \
    --project "${PROJECT}" \
    --quiet \
    --zone "${ZONE}" \
    "${MASTER_NAME}"-pd || true

  # Find out what minions are running.
  local -a minions
  minions=( $(gcloud compute instances list \
                --project "${PROJECT}" --zone "${ZONE}" \
                --regexp "${NODE_INSTANCE_PREFIX}-.+" \
                | awk 'NR >= 2 { print $1 }') )
  # If any minions are running, delete them in batches.
  while (( "${#minions[@]}" > 0 )); do
    echo Deleting nodes "${minions[*]::10}"
    gcloud compute instances delete \
      --project "${PROJECT}" \
      --quiet \
      --delete-disks boot \
      --zone "${ZONE}" \
      "${minions[@]::10}" || true
    minions=( "${minions[@]:10}" )
  done

  # Delete firewall rule for the master.
  gcloud compute firewall-rules delete  \
    --project "${PROJECT}" \
    --quiet \
    "${MASTER_NAME}-https" || true

  # Delete firewall rule for minions.
  gcloud compute firewall-rules delete  \
    --project "${PROJECT}" \
    --quiet \
    "${MINION_TAG}-all" || true

  # Delete routes.
  local -a routes
  routes=( $(gcloud compute routes list --project "${PROJECT}" \
              --regexp "${NODE_INSTANCE_PREFIX}-.+" | awk 'NR >= 2 { print $1 }') )
  routes+=("${MASTER_NAME}")
  while (( "${#routes[@]}" > 0 )); do
    echo Deleting routes "${routes[*]::10}"
    gcloud compute routes delete \
      --project "${PROJECT}" \
      --quiet \
      "${routes[@]::10}" || true
    routes=( "${routes[@]:10}" )
  done

  # Delete the master's reserved IP
  local REGION=${ZONE%-*}
  gcloud compute addresses delete \
    --project "${PROJECT}" \
    --region "${REGION}" \
    --quiet \
    "${MASTER_NAME}-ip" || true

  export KUBECONFIG="${HOME}/.kube/.kubeconfig"
  export CONTEXT="${PROJECT}_${INSTANCE_PREFIX}"
  clear-kubeconfig
}

# Update a kubernetes cluster with latest source
function kube-push {
  OUTPUT=${KUBE_ROOT}/_output/logs
  mkdir -p ${OUTPUT}

  ensure-temp-dir
  detect-project
  detect-master
  detect-minion-names
  get-password
  set-master-htpasswd

  # Make sure we have the tar files staged on Google Storage
  find-release-tars
  upload-server-tars

  write-master-env
  add-instance-metadata-from-file "${KUBE_MASTER}" "kube-env=${KUBE_TEMP}/master-kube-env.yaml"
  echo "Pushing to master (log at ${OUTPUT}/kube-push-${KUBE_MASTER}.log) ..."
  cat ${KUBE_ROOT}/cluster/gce/configure-vm.sh | gcloud compute ssh --ssh-flag="-o LogLevel=quiet" --project "${PROJECT}" --zone "${ZONE}" "${KUBE_MASTER}" --command "sudo bash -s -- --push" &> ${OUTPUT}/kube-push-"${KUBE_MASTER}".log

  echo "Pushing metadata to minions... "
  write-node-env
  for (( i=0; i<${#MINION_NAMES[@]}; i++)); do
    add-instance-metadata-from-file "${MINION_NAMES[$i]}" "kube-env=${KUBE_TEMP}/node-kube-env.yaml" &
  done
  wait-for-jobs
  echo "Done"

  for (( i=0; i<${#MINION_NAMES[@]}; i++)); do
    echo "Starting push to node (log at ${OUTPUT}/kube-push-${MINION_NAMES[$i]}.log) ..."
    cat ${KUBE_ROOT}/cluster/gce/configure-vm.sh | gcloud compute ssh --ssh-flag="-o LogLevel=quiet" --project "${PROJECT}" --zone "${ZONE}" "${MINION_NAMES[$i]}" --command "sudo bash -s -- --push" &> ${OUTPUT}/kube-push-"${MINION_NAMES[$i]}".log &
  done

  echo -n "Waiting for node pushes... "
  wait-for-jobs
  echo "Done"

  # TODO(zmerlynn): Re-create instance-template with the new
  # node-kube-env. This isn't important until the node-ip-range issue
  # is solved (because that's blocking automatic dynamic nodes from
  # working). The node-kube-env has to be composed with the kube-token
  # metadata. Ideally we would have
  # https://github.com/GoogleCloudPlatform/kubernetes/issues/3168
  # implemented before then, though, so avoiding this mess until then.

  echo
  echo "Kubernetes cluster is running.  The master is running at:"
  echo
  echo "  https://${KUBE_MASTER_IP}"
  echo
  echo "The user name and password to use is located in ~/.kubernetes_auth."
  echo
}

# -----------------------------------------------------------------------------
# Cluster specific test helpers used from hack/e2e-test.sh

# Execute prior to running tests to build a release if required for env.
#
# Assumed Vars:
#   KUBE_ROOT
function test-build-release {
  # Make a release
  "${KUBE_ROOT}/build/release.sh"
}

# Execute prior to running tests to initialize required structure. This is
# called from hack/e2e.go only when running -up (it is run after kube-up).
#
# Assumed vars:
#   Variables from config.sh
function test-setup {
  # Detect the project into $PROJECT if it isn't set
  detect-project

  # Open up port 80 & 8080 so common containers on minions can be reached
  # TODO(roberthbailey): Remove this once we are no longer relying on hostPorts.
  gcloud compute firewall-rules create \
    --project "${PROJECT}" \
    --target-tags "${MINION_TAG}" \
    --allow tcp:80 tcp:8080 \
    --network "${NETWORK}" \
    "${MINION_TAG}-${INSTANCE_PREFIX}-http-alt"
}

# Execute after running tests to perform any required clean-up. This is called
# from hack/e2e.go
function test-teardown {
  detect-project
  echo "Shutting down test cluster in background."
  gcloud compute firewall-rules delete  \
    --project "${PROJECT}" \
    --quiet \
    "${MINION_TAG}-${INSTANCE_PREFIX}-http-alt" || true
  "${KUBE_ROOT}/cluster/kube-down.sh"
}

# SSH to a node by name ($1) and run a command ($2).
function ssh-to-node {
  local node="$1"
  local cmd="$2"
  for try in $(seq 1 5); do
    if gcloud compute ssh --ssh-flag="-o LogLevel=quiet" --project "${PROJECT}" --zone="${ZONE}" "${node}" --command "${cmd}"; then
      break
    fi
  done
}

# Restart the kube-proxy on a node ($1)
function restart-kube-proxy {
  ssh-to-node "$1" "sudo /etc/init.d/kube-proxy restart"
}

# Restart the kube-apiserver on a node ($1)
function restart-apiserver {
  ssh-to-node "$1" "sudo /etc/init.d/kube-apiserver restart"
}

# Perform preparations required to run e2e tests
function prepare-e2e() {
  detect-project
}
