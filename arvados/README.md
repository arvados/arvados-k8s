[//]: # Copyright (C) The Arvados Authors. All rights reserved.
[//]: #
[//]: # SPDX-License-Identifier: Apache-2.0

# Arvados Helm Chart

This directory contains a simple Helm chart for Arvados, excluding the Git
server and SLURM. It's more or less a port of the Kubernetes config generated
by the Arvados Kelda blueprint.

The files should only be considered an example of what a Kubernetes deployment
might look like -- this is my first Helm chart, and there are definitely things
that could be cleaner.

## Usage

1. Boot a [GKE cluster](https://console.cloud.google.com/kubernetes/) with at least 3 nodes.
    - I tested with 3 n1-standard-1 (1 vCPU, 3.75GB RAM) machines on Kubernetes v1.8.8.
    - It takes a few minutes for the cluster to be initialized.

2. Reserve a [static IP](https://console.cloud.google.com/networking/addresses) in GCE.
    - Make sure the IP is in the same region as your GKE cluster, and is of the
      "Regional" type.

3. Install `gcloud`, `kubectl`, and `helm` on your development machine.
   `gcloud` is used to setup the connection to your GKE cluster. `kubectl` is
   used to interact with the Kubernetes cluster. `helm` is used to deploy to
   the cluster.
     - Follow the instructions [here](https://cloud.google.com/sdk/downloads) to install `gcloud`.
     - `gcloud components install kubectl` to install `kubectl`.
     - `brew install kubernetes-helm` to install `helm`.
     - If that doesn't work, see the official installation instructions for
       [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl)
       and [helm](https://docs.helm.sh/using_helm/#installing-helm).

3. Connect to the GKE cluster.
    - Click the "Connect" button next to your [GKE cluster](https://console.cloud.google.com/kubernetes/).
    - Execute the "Command-line access" command on your development machine.
    - Run `kubectl get nodes` to test your connection to the GKE cluster. The
      nodes you specified in step 1 should show up in the output.

4. Install `helm` on the cluster.
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

5. Generate an SSL certificate.
    - Run `./cert-gen.sh <STATIC IP>` where `<STATIC IP>` is the IP allocated in step 1.

6. *Optional*: Trust the generated certificate. By default, browsers treat
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

7. Modify the Kubernetes configs to reference your static IP.
    - Replace all references to the IP `8.8.8.8` with the IP allocated in step 1.
    - This can be done automatically with the following command:
        ```
        grep -lr --exclude README.md '8.8.8.8' . | xargs sed -i '' 's/8.8.8.8/<STATIC IP>/g'
        ```
8. Install the Arvados Kubernetes configs.
    - Run `helm install --name arvados .`
    - If you make a change to the Kubernetes manifests and want to reinstall
      the configs, run `helm delete --purge arvados`, followed by the `helm
      install` command.

9. Wait for everything to boot in the cluster. This takes a few minutes from my
   testing.
    - `kubectl get pods` should show all the pods as running.
    - `kubectl get services` shouldn't show anything as `<pending>`.
        - If some services are stuck in `<pending>` check their status with
          `kubectl describe service/serviceName` (e.g. `kubectl describe
          service/arvados-api-server`). If there's an error along the lines of
          "Specified IP address is in-use and would result in a conflict.",
          manually delete all entries under "Forwarding rules" and "Target
          pools" in the [console UI](https://console.cloud.google.com/net-services/loadbalancing/advanced/targetPools/list).
    - Even after the containers are running, they take a couple minutes to
      download and install various packages. If some components seem down,
      check its logs with `kubectl logs <POD NAME>` and see if it's fully
      initialized. In my testing, the container has been inaccessible for up to
      10 minutes after starting.

10. Connect to the Workbench.
    - Navigate to `https://<STATIC IP>` in your browser.

11. Destroy the GKE cluster when finished.

## Future Work

- The Arvados Dockerfiles need to be rebuilt so that they have the latest `apt`
  metadata. As a workaround, some pods, such as `keep-web` are running `apt-get
  update` when they start.
- Set the floating IP through `./values.yaml` and have Helm handling templating
  it, rather than manually replacing references to the IP.
    - There may be other values worth templating, such as the number of Keep
      containers to deploy, or the versions of the Arvados packages to install.
- Figure out a better way of setting API tokens. It's currently hardcoded in
  the config files, and changing it in one location will cause the other
  references to fail.
    ```
    $ grep -r 'thisisnotavery' .
    ./config/api-server/90-init-db.sh:    bundle exec script/create_superuser_token.rb thisisnotaverygoodsuperusersecretstring00000000000
    ./config/api-server/90-init-db.sh:    bundle exec get_anonymous_user_token.rb -t thisisnotaverygoodanonymoussecretstring00000000000 || true
    ./config/sso/90-init-db.sh:    bundle exec script/create_superuser_token.rb thisisnotaverygoodsuperusersecretstring00000000000
    ./config/sso/90-init-db.sh:    bundle exec get_anonymous_user_token.rb -t thisisnotaverygoodanonymoussecretstring00000000000 || true
    ./templates/keep-proxy-deployment.yaml:              value: "thisisnotaverygoodanonymoussecretstring00000000000"
    ./templates/keep-web-deployment.yaml:              value: "thisisnotaverygoodanonymoussecretstring00000000000"
    ./templates/shell-server-deployment.yaml:              value: "thisisnotaverygoodsuperusersecretstring00000000000"
    ```
- Figure out how to reduce redundant YAML files.
    - The Nginx SSL proxies (`./templates/keep-web-https.yaml`,
      `./templates/keep-proxy-https.yaml`, `./templates/ws-https.yaml`) are
      extremely similar. Only a couple lines related to hostnames and
      ports different.
    - The configmap YAMLs are all basically the same.
    - This might be possible with partials (a Helm templating feature). Or in a
      different templating language such as ksonnet.
- Add SLURM support
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
- Add SSL to SSO server
    - It's currently being hosted on only HTTP.
