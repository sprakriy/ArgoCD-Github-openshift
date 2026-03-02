kubectl get secret aws-creds --namespace=my-onboarding-project -o json | \
  sed 's/"namespace": "my-onboarding-project"/"namespace": "tf-gate"/' | \
  kubectl apply -f tf-gate-aws-creds-tekton.yaml
