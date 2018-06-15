[//]: # Copyright (C) The Arvados Authors. All rights reserved.
[//]: #
[//]: # SPDX-License-Identifier: Apache-2.0

# Arvados Helm Chart

This directory contains a simple Helm chart for Arvados, excluding the Git
server. This is an initial version, there is (a lot of) room for improvement.

**WARNING**

This Helm chart does not retain any state after it is deleted. An Arvados
cluster spun up with this Helm Chart is entirely ephemeral.

**/WARNING**

## Usage example (GKE)

1. Install `gcloud`, `kubectl`, and `helm` on your development machine.
   `gcloud` is used to setup the connection to your GKE cluster. `kubectl` is
   used to interact with the Kubernetes cluster. `helm` is used to deploy to
   the cluster.
     - Follow the instructions [here](https://cloud.google.com/sdk/downloads) to install `gcloud`.
     - `gcloud components install kubectl` to install `kubectl`.
     - Follow the instructions [here](//docs.helm.sh/using_helm/#installing-helm) to install `helm`.
     - If that doesn't work, see the official installation instructions for
       [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl)
       and [helm](https://docs.helm.sh/using_helm/#installing-helm).

2. Boot a [GKE cluster](https://console.cloud.google.com/kubernetes/) with at
   least 3 nodes, n1-standard-2 or larger.

   Kubernetes 1.10 is required, because this chart uses the binaryData configmap feature.

   It is also possible to boot the cluster from the command line:

     gcloud container clusters create <CLUSTERNAME> --zone us-central1-a --machine-type n1-standard-2 --cluster-version 1.10.2-gke.3

   It takes a few minutes for the cluster to be initialized.

3. Reserve a [static IP](https://console.cloud.google.com/networking/addresses) in GCE.
    - Make sure the IP is in the same region as your GKE cluster, and is of the
      "Regional" type.

4. Connect to the GKE cluster.

   Web:
    - Click the "Connect" button next to your [GKE cluster](https://console.cloud.google.com/kubernetes/).
    - Execute the "Command-line access" command on your development machine.

   Alternatively, use this command:
    - gcloud container clusters get-credentials <CLUSTERNAME> --zone us-central1-a --project <YOUR-PROJECT>

  Test:
    - Run `kubectl get nodes` to test your connection to the GKE cluster. The
      nodes you specified in step 2 should show up in the output.

5. Install `helm` on the cluster.
    - Run the following commands from your development machine. The last three
      commands are necessary since GKE clusters use RBAC for authentication, so
      the default `helm` installation doesn't have sufficient permissions to
      deploy to the cluster:
        - `helm init`
        - `kubectl create serviceaccount --namespace kube-system tiller`
        - `kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller`
        - `kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'`
    - Wait until the `tiller` container's status is "Running" in `kubectl get pods --namespace kube-system`
    - Test `helm` by running `helm ls`. There shouldn't be any errors.

6. Generate an SSL certificate.
    - Run `./cert-gen.sh <STATIC IP>` where `<STATIC IP>` is the IP allocated in step 1.

7. *Optional*: Trust the generated certificate. By default, browsers treat
   self-signed certificates as insecure. Therefore, the generated certificate
   must be manually trusted through the OS settings.  If you skip this step,
   you'll have to manually override browser SSL warnings when connecting to
   workbench.

   To do this on On Mac OS:
   1. Open the "Keychain Access" application.
   2. Click "File" in the menu at the top left.
   3. Click "Import Items...".
   4. Navigate to the generated `cert` and click "Open".
   5. Double click on the certificate and change the trust level to "Always
      Trust". The certificate will be named "arvados-test-cert".

8. Install the Arvados Kubernetes configs.
    - Run `helm install --name arvados . --set externalIP=<YOUR-OFFICIAL-IP>`
    - If you make a change to the Kubernetes manifests and want to reinstall
      the configs, run `helm delete --purge arvados`, followed by the `helm
      install` command.

9. Wait for everything to boot in the cluster. This takes about 5 minutes.
    - `kubectl get pods` should show all the pods as running.
    - `kubectl get services` shouldn't show anything as `<pending>`.
        - If some services are stuck in `<pending>` check their status with
          `kubectl describe service/serviceName` (e.g. `kubectl describe
          service/arvados-api-server`). If there's an error along the lines of
          "Specified IP address is in-use and would result in a conflict.",
          manually delete all entries under "Forwarding rules" and "Target
          pools" in the [console UI](https://console.cloud.google.com/net-services/loadbalancing/advanced/targetPools/list).
    - Even after the containers are running, they take a couple minutes to
      download and install various packages. If some component seem down,
      check its logs with `kubectl logs <POD NAME>` and see if it's fully
      initialized.

10. Connect to Workbench:
    - Navigate to `https://<STATIC IP>` in your browser. Use the username and
      password specified in values.yaml to log in.

    Alternatively, use the Arvados cli tools or SDKs:

    Set the environment variables properly:

    ARVADOS_API_TOKEN=<superUserSecret from values.yaml>
    ARVADOS_API_HOST=<STATIC IP>:444
    ARVADOS_API_HOST_INSECURE=true

11. Destroy the GKE cluster when finished, via the web or command line:
    - helm del arvados --purge
    - gcloud container clusters delete <CLUSTERNAME> --zone us-central1-a

## Future Work

- Add an option to use an external PostgreSQL database
- Add an option to use an external Keep storage backend
- Add Arvados Docker Cleaner to the compute nodes.
- Figure out how to reduce redundant YAML files.
    - The Nginx SSL proxies (`./templates/keep-web-https.yaml`,
      `./templates/keep-proxy-https.yaml`, `./templates/ws-https.yaml`) are
      extremely similar. Only a couple lines related to hostnames and
      ports different.
    - The configmap YAMLs are all basically the same.
    - This might be possible with partials (a Helm templating feature). Or in a
      different templating language such as ksonnet.
- Support changing keep-store scale. Right now the scale is set to `replicas:
  2` in `templates/keep-store-deployment.yaml`. Unfortunately, increasing the scale
  isn't as simple as changing the number since the hostnames are hardcoded in
  `config/shell-server/99-init-keep.sh`.
- Consider adding healthchecks and readiness checks.
    - They would make the deployment more robust. Readiness checks would make
      it so services weren't exposed until they're ready to receive traffic.
      Healthchecks would make it so containers are restarted when they enter a
      failure state.
- Add minimum CPU and RAM requirements to the containers.
    - This will prevent out of memory errors, for example. This is especially
      important if autoscaling is added.
- Get the SSL certificate automatically using Lets Encrypt, eliminating the
  need for the self-signed certificate generated by the `cert-gen.sh` script.
