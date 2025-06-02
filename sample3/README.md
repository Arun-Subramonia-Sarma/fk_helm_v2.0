# Generic Workload Helm Chart

A comprehensive, production-ready Helm chart that supports all major Kubernetes workload types with advanced features for complex enterprise deployments.

## 🚀 Key Features

- **Universal Pod Template**: Single reusable template for all workload types
- **Business Labels**: Automatic bu, project, application, env labels on all resources
- **Multiple Resource Support**: Services, ConfigMaps, Secrets, Ingresses
- **Advanced Environment Variables**: key=value format + valueFrom support
- **Environment-Specific Ingress**: Active/Preview versions with different configurations
- **Unified Job Management**: Single template for all job types
- **Extensive Customization**: Labels and annotations at every level

## 🏗️ Supported Workloads

| Workload | Configuration | Multiple Support | Pod Selector Labels |
|----------|--------------|------------------|-------------------|
| Deployment | `workload.deployment` | ❌ Single | Standard + Business |
| StatefulSet | `workload.statefulset` | ❌ Single | Standard + Business |
| DaemonSet | `workload.daemonset` | ❌ Single | Standard + Business |
| Job | `jobs.*` | ✅ Multiple | Standard + Business + jobname |
| CronJob | `cronjobs.*` | ✅ Multiple | Standard + Business + jobname |
| Argo Rollout | `workload.rollout` | ❌ Single | Standard + Business |

## 📋 Business Labels

All resources automatically receive these labels:

```yaml
businessLabels:
  bu: "engineering"      # Business Unit
  project: "api-service" # Project name
  application: "backend" # Application name
  env: "production"      # Environment
```

These labels are included in pod selectors for consistent resource targeting.

## 🌍 Environment Variables

### Key=Value Format
Environment variables are defined in simple key=value format:

```yaml
envVars:
  DATABASE_URL: "postgresql://localhost:5432/mydb"
  DEBUG: "true"
  PORT: "8080"
  API_TIMEOUT: "30"
```

This gets automatically converted to the standard Kubernetes format:
```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://localhost:5432/mydb"
  - name: DEBUG
    value: "true"
```

### ValueFrom Support
Reference secrets, configmaps, and field values:

```yaml
envValueFrom:
  DATABASE_PASSWORD:
    secretKeyRef:
      name: db-secret
      key: password
  NODE_NAME:
    fieldRef:
      fieldPath: spec.nodeName
  CONFIG_VALUE:
    configMapKeyRef:
      name: app-config
      key: config-key
```

## 🔗 Multiple Resources

### Multiple Services
```yaml
services:
  api:
    enabled: true
    type: ClusterIP
    port: 80
    targetPort: 8080
    labels:
      service-type: "api"
  
  admin:
    enabled: true
    type: NodePort
    port: 9090
    targetPort: 9090
    nodePort: 30090
```

### Multiple ConfigMaps
```yaml
configMaps:
  app-config:
    enabled: true
    data:
      config.yaml: |
        database:
          host: postgres
          port: 5432
      app.properties: |
        debug=true
  
  nginx-config:
    enabled: true
    data:
      nginx.conf: |
        server {
          listen 80;
          location / {
            proxy_pass http://backend;
          }
        }
```

### Multiple Secrets
```yaml
secrets:
  db-credentials:
    enabled: true
    type: Opaque
    data:
      username: cG9zdGdyZXM=  # base64 encoded
      password: c2VjcmV0cGFzcw==
  
  api-keys:
    enabled: true
    type: Opaque
    stringData:  # Plain text (auto-encoded)
      stripe-key: "sk_live_..."
      jwt-secret: "super-secret-key"
```

## 🌐 Advanced Ingress with Active/Preview Support

The chart supports creating separate ingresses for active and preview environments based on your specific structure:

```yaml
ingress:
  # Global labels/annotations for all ingresses
  labels:
    team: "platform"
  labels_active:
    environment: "production"
  labels_preview:
    environment: "staging"
  annotations:
    kubernetes.io/ingress.class: "nginx"
  annotations_active:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  annotations_preview:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
  
  data:
    fk-ingress:
      enabled: true
      # Ingress-specific labels/annotations
      labels:
        ingress-purpose: "main-api"
      annotations:
        appgw.ingress.kubernetes.io/request-timeout: "120"
      annotations_active:
        appgw.ingress.kubernetes.io/appgw-ssl-certificate: wildcard-fourkites-ssl
      annotations_preview:
        appgw.ingress.kubernetes.io/appgw-ssl-certificate: ng-fourkites-com-wildcard-cert
      className: "azure-application-gateway"
      hosts:
        - host: dy.fourkites.com
          host_preview: dy-preview.ng.fourkites.com
          paths:
            - path: /api/*
              pathType: ImplementationSpecific
            - path: /auth/*
              pathType: ImplementationSpecific
```

### How Ingress Active/Preview Works

1. **When `host_preview` is present**: Two ingresses are created
   - `my-app-fk-ingress` (active version with `host`)
   - `my-app-fk-ingress-preview` (preview version with `host_preview`)

2. **Label and Annotation Merging**:
   - **Common**: Applied to both versions
   - **_active**: Only applied to active version
   - **_preview**: Only applied to preview version

3. **Merge Priority** (later overrides earlier):
   - Global ingress labels/annotations
   - Global active/preview labels/annotations
   - Ingress-specific labels/annotations
   - Ingress-specific active/preview labels/annotations

## 🔄 Jobs and CronJobs

### Multiple Jobs
All jobs use the same universal pod template:

```yaml
jobs:
  db-migration:
    enabled: true
    backoffLimit: 3
    restartPolicy: Never
    image:
      repository: migration-tool
      tag: "v1.0"
    command: ["python", "migrate.py"]
    envVars:
      MIGRATION_TYPE: "schema"
    envValueFrom:
      DB_PASSWORD:
        secretKeyRef:
          name: db-secret
          key: password
    labels:
      migration-phase: "pre-deploy"
    podLabels:
      resource-intensive: "true"
  
  data-import:
    enabled: true
    completions: 5
    parallelism: 2
    command: ["./import.sh"]
    labels:
      job-type: "data-processing"
```

### Multiple CronJobs
```yaml
cronjobs:
  daily-backup:
    enabled: true
    schedule: "0 2 * * *"
    concurrencyPolicy: Forbid
    command: ["backup.sh"]
    envVars:
      BACKUP_TYPE: "full"
    jobTemplate:
      backoffLimit: 2
      restartPolicy: OnFailure
  
  weekly-cleanup:
    enabled: true
    schedule: "0 0 * * 0"
    command: ["cleanup.sh", "--age", "7d"]
```

Each job/cronjob automatically gets:
- Business labels (bu, project, application, env)
- Additional `jobname` label
- Ability to override any global setting

## 📁 Chart Structure

```
generic-workload-chart/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl              # Universal pod template & helpers
│   ├── workload.yaml             # Deployment, StatefulSet, DaemonSet, Rollout
│   ├── jobs.yaml                 # Multiple jobs
│   ├── cronjobs.yaml             # Multiple cronjobs
│   ├── services.yaml             # Multiple services
│   ├── configmaps.yaml           # Multiple configmaps
│   ├── secrets.yaml              # Multiple secrets
│   ├── ingress.yaml              # Advanced ingress with active/preview
│   ├── serviceaccount.yaml       # Service account
│   ├── hpa.yaml                  # Horizontal Pod Autoscaler
│   └── pdb.yaml                  # Pod Disruption Budget
└── examples/
    ├── basic-deployment.yaml
    ├── multi-job-example.yaml
    └── production-example.yaml
```

## 🚀 Quick Start Examples

### 1. Basic Deployment
```yaml
businessLabels:
  bu: "engineering"
  project: "my-api"
  application: "backend"
  env: "production"

workload:
  type: deployment
  deployment:
    replicas: 3

image:
  repository: my-company/api
  tag: "v1.0"

services:
  api:
    enabled: true
    port: 80
    targetPort: 8080
```

### 2. Complex Multi-Service Application
```yaml
businessLabels:
  bu: "platform"
  project: "ecommerce"
  application: "api"
  env: "production"

# Main application
workload:
  type: deployment
  deployment:
    replicas: 5

# Migration job
jobs:
  migration:
    enabled: true
    command: ["migrate", "--env", "prod"]

# Multiple services
services:
  api:
    enabled: true
    port: 80
    targetPort: 8080
  admin:
    enabled: true
    port: 9090
    targetPort: 9090

# Advanced ingress
ingress:
  data:
    main:
      enabled: true
      hosts:
        - host: api.company.com
          host_preview: api-staging.company.com
          paths:
            - path: /api/*
              pathType: ImplementationSpecific
```

## 🔧 Installation & Usage

### Install the Chart
```bash
# Add repository (if hosted)
helm repo add my-charts https://charts.company.com

# Install with default values
helm install my-app my-charts/generic-workload-chart

# Install with custom values
helm install my-app my-charts/generic-workload-chart -f production-values.yaml

# Install with inline overrides
helm install my-app my-charts/generic-workload-chart \
  --set businessLabels.bu=engineering \
  --set businessLabels.project=my-api \
  --set workload.deployment.replicas=5
```

### Upgrade and Manage
```bash
# Upgrade with new values
helm upgrade my-app my-charts/generic-workload-chart -f updated-values.yaml

# Debug and validate
helm template my-app my-charts/generic-workload-chart -f values.yaml --debug

# Check current values
helm get values my-app

# Rollback if needed
helm rollback my-app 1
```

## 🏷️ Label and Annotation Management

### Workload-Level Customization
```yaml
# Global workload labels (applied to all workloads)
workloadLabels:
  team: "platform"
  cost-center: "engineering"

# Workload-specific
workload:
  deployment:
    labels:
      tier: "frontend"
    annotations:
      deployment.kubernetes.io/revision: "3"
```

### Pod-Level Customization
```yaml
# Global pod labels (applied to all pods)
podLabels:
  monitoring: "enabled"
  backup: "daily"

# Job-specific pod labels
jobs:
  migration:
    podLabels:
      resource-intensive: "true"
      priority: "high"
```

## 🔒 Security Best Practices

### Pod Security
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
```

### Secret Management
```yaml
secrets:
  app-secrets:
    enabled: true
    type: Opaque
    stringData:  # Use stringData for non-encoded secrets
      api-key: "secret-value"
    annotations:
      # Integrate with external secret managers
      external-secrets.io/backend: "vault"
```

## 📊 Monitoring and Observability

```yaml
# Health checks
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5

# Metrics service
services:
  metrics:
    enabled: true
    port: 9090
    targetPort: 9090
    labels:
      monitoring: "prometheus"

# Pod labels for monitoring
podLabels:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
```

## 🔄 CI/CD Integration

### GitOps Example
```yaml
# values-prod.yaml
businessLabels:
  env: "production"
image:
  tag: "${CI_COMMIT_SHA}"

# values-staging.yaml  
businessLabels:
  env: "staging"
image:
  tag: "${CI_COMMIT_SHA}"
```

### Pipeline Integration
```bash
# Deploy to staging
helm upgrade --install my-app-staging ./chart \
  -f values-staging.yaml \
  --set image.tag=${CI_COMMIT_SHA}

# Deploy to production (with approval)
helm upgrade --install my-app-prod ./chart \
  -f values-prod.yaml \
  --set image.tag=${CI_COMMIT_SHA}
```

## 🐛 Troubleshooting

### Debug Template Rendering
```bash
# Render templates without installing
helm template my-app ./chart -f values.yaml

# Debug with verbose output
helm install my-app ./chart -f values.yaml --dry-run --debug

# Validate templates
helm lint ./chart
```

### Common Issues

1. **Environment Variables Not Working**
   - Check `envVars` format (key: value, not key=value in YAML)
   - Verify `envValueFrom` references exist

2. **Ingress Not Creating Preview Version**
   - Ensure `host_preview` is specified in hosts
   - Check `annotations_preview` and `labels_preview` syntax

3. **Jobs Not Getting Business Labels**
   - Business labels are automatically applied
   - Check if `businessLabels` section is properly configured

4. **Pod Selectors Not Matching**
   - Business labels are included in selectors
   - Ensure consistent business label values

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test with different workload combinations
4. Update documentation
5. Submit a pull request

## 📄 License

This chart is licensed under the Apache 2.0 License.