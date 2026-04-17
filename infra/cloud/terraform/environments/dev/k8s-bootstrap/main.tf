# ── Remote state ──────────────────────────────────────────────────────────────

data "terraform_remote_state" "compute" {
  backend = "s3"
  config = {
    bucket = "link-vault-tf-backend"
    key    = "dev/compute/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "link-vault-tf-backend"
    key    = "dev/network/terraform.tfstate"
    region = "us-east-1"
  }
}

# ── Namespace ─────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ── ArgoCD ────────────────────────────────────────────────────────────────────
# Deployed on the system node group (taint: dedicated=system:NoSchedule).
# Single-replica (non-HA) is appropriate for dev — set ha.enabled=true for prod.

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  # Wait for all ArgoCD pods to be Ready before Terraform considers this done.
  wait    = true
  timeout = 600

  values = [
    yamlencode({
      global = {
        # Schedule all ArgoCD components on the system node group.
        tolerations = [{
          key      = "dedicated"
          value    = "system"
          effect   = "NoSchedule"
          operator = "Equal"
        }]
        nodeSelector = {
          role = "system"
        }
      }

      configs = {
        params = {
          # Disable TLS on the argocd-server — TLS is terminated at the
          # Gateway/load balancer layer, not inside the pod.
          "server.insecure" = true
        }
      }

      server = {
        service = {
          type = "ClusterIP"
        }
      }

      # Non-HA for dev. In prod set ha.enabled = true on each component.
      redis = {
        tolerations = [{
          key      = "dedicated"
          value    = "system"
          effect   = "NoSchedule"
          operator = "Equal"
        }]
        nodeSelector = { role = "system" }
      }

      repoServer = {
        tolerations = [{
          key      = "dedicated"
          value    = "system"
          effect   = "NoSchedule"
          operator = "Equal"
        }]
        nodeSelector = { role = "system" }
      }

      applicationSet = {
        tolerations = [{
          key      = "dedicated"
          value    = "system"
          effect   = "NoSchedule"
          operator = "Equal"
        }]
        nodeSelector = { role = "system" }
      }

      notifications = {
        tolerations = [{
          key      = "dedicated"
          value    = "system"
          effect   = "NoSchedule"
          operator = "Equal"
        }]
        nodeSelector = { role = "system" }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}
