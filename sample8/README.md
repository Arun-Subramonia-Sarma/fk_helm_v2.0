# Generic Workload Helm Chart

A comprehensive, production-ready Helm chart that supports all major Kubernetes workload types with advanced features for complex enterprise deployments.

## 🚀 Key Features

- **Universal Pod Template**: Single reusable template for all workload types
- **Business Labels**: Automatic bu, project, application, env labels on all resources
- **Multiple Resource Support**: Services, ConfigMaps, Secrets, Ingresses
- **Advanced Environment Variables**: key=value format + valueFrom support
- **Environment-Specific Ingress**: Active/Preview versions with different configurations
- **Unified Job Management**: Single template for all job types
- **Flexible Secret/ConfigMap Mounting**: Auto-mount as volumes OR environment variables
- **External Secrets Integration**: Full support with volume mounting capabilities
- **Extensive Customization**: Labels and annotations at every level

## 🏗️ Supported Workloads

| Workload | Configuration | Multiple Support | Pod Selector Labels | Strategy Support |
|----------|--------------|------------------|-------------------|------------------|
| Deployment | `workload.deployment` | ❌ Single | Standard + Business | RollingUpdate, Recreate |
| StatefulSet | `workload.statefulset` | ❌ Single | Standard + Business | RollingUpdate, OnDelete |
| DaemonSet | `workload.daemonset` | ❌ Single | Standard + Business | RollingUpdate, OnDelete |
| Job | `jobs.*` | ✅ Multiple | Standard + Business + jobname | N/A |
| CronJob | `cronjobs.*` | ✅ Multiple | Standard + Business + jobname | N/A |
| Argo Rollout | `workload.rollout` | ❌ Single | Standard + Business | Canary, Blue-Green |

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

## 🔗 Multiple Resources with Smart Mounting

### Multiple ConfigMaps

**🆕 NEW: Auto-mounting based on `mountPath`**

ConfigMaps can now be automatically mounted as volumes OR loaded as environment variables:

```yaml
configMaps:
  # Environment Variables (no mountPath) - Added to envFrom
  app-config:
    enabled: true
    data:
      DATABASE_HOST: "postgres"
      DEBUG_MODE: "true"
      LOG_LEVEL: "info"
  
  # Volume Mount (with mountPath) - Mounted as volume
  nginx-config:
    enabled: true
    mountPath: /etc/nginx/conf.d
    readOnly: true              # Optional: defaults to true
    defaultMode: 0644          # Optional: defaults to 420 (0644)
    subPath: nginx.conf        # Optional: mount specific file
    items:                     # Optional: select specific keys
      - key: nginx.conf
        path: default.conf
        mode: 0644
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

**🆕 NEW: Auto-mounting based on `mountPath`**

Secrets can be automatically mounted as volumes OR loaded as environment variables:

```yaml
secrets:
  # Environment Variables (no mountPath) - Added to envFrom
  db-credentials:
    enabled: true
    type: Opaque
    stringData:
      USERNAME: "postgres"
      PASSWORD: "secretpass"
      DATABASE_URL: "postgresql://postgres:secretpass@db:5432/myapp"
  
  # Volume Mount (with mountPath) - Mounted as volume
  ssl-certs:
    enabled: true
    type: kubernetes.io/tls
    mountPath: /etc/ssl/certs
    readOnly: true              # Optional: defaults to true
    defaultMode: 0400          # Optional: stricter permissions for certs
    items:                     # Optional: control file names and permissions
      - key: tls.crt
        path: server.crt
        mode: 0444
      - key: tls.key
        path: server.key
        mode: 0400
    data:
      tls.crt: LS0tLS1CRUdJTi...  # base64 encoded cert
      tls.key: LS0tLS1CRUdJTi...  # base64 encoded key
  
  # JSON/Binary files that need mounting
  service-account-key:
    enabled: true
    mountPath: /var/secrets/google
    subPath: key.json          # Mount as single file
    data:
      key.json: ewogICJ0eXBlIjog...  # base64 encoded JSON
```

### External Secrets

**🆕 NEW: Auto-mounting support**

External Secrets now support the same mounting behavior:

```yaml
externalSecrets:
  enabled: true
  refreshInterval: "30s"
  name: "vault-secret-store"
  kind: "SecretStore"
  cloud: "aws"
  
  es:
    # Environment Variables (no mountPath) - Added to envFrom
    database-creds:
      data:
        username:
          key: "prod/database"
          property: "username"
        password:
          key: "prod/database" 
          property: "password"
    
    # Volume Mount (with mountPath) - Mounted as volume
    ssl-certificates:
      mountPath: /etc/ssl/external
      readOnly: true
      defaultMode: 0400
      items:
        - key: tls.crt
          path: server.crt
          mode: 0444
      dataFrom:
        - extract:
            key: "prod/ssl-certs"
    
    # Extract entire secret as environment variables
    api-keys:
      dataFrom:
        - extract:
            key: "prod/api-keys"
    
    # Find multiple secrets by pattern
    certificates:
      mountPath: /etc/ssl/auto
      dataFrom:
        - find:
            name:
              regexp: "ssl-.*-cert"
```

## 🔄 How Auto-Mounting Works

The chart automatically determines how to handle secrets, configmaps, and external secrets:

### Without `mountPath` → Environment Variables
- **Secrets**: Added to `envFrom` as `secretRef`
- **ConfigMaps**: Added to `envFrom` as `configMapRef`
- **External Secrets**: Added to `envFrom` as `secretRef`

### With `mountPath` → Volume Mounts
- **Secrets**: Mounted as `secret` volume
- **ConfigMaps**: Mounted as `configMap` volume
- **External Secrets**: Mounted as `secret` volume (created by External Secrets Operator)

### Volume Mount Options

All resources with `mountPath` support these options:

```yaml
mountPath: /path/in/container    # Required: where to mount
readOnly: true                   # Optional: defaults to true
defaultMode: 0644               # Optional: default file permissions (420 decimal)
subPath: filename.ext           # Optional: mount single file instead of directory
items:                          # Optional: select and rename specific keys
  - key: source-key
    path: target-filename
    mode: 0600                  # Optional: per-file permissions
```

## 🚀 Argo Rollouts Advanced Deployment Strategies

The chart supports advanced deployment strategies using Argo Rollouts, including both canary and blue-green deployments with comprehensive traffic management and analysis capabilities.

## 🔵 Blue-Green Deployment Strategy

Blue-Green deployment maintains two identical production environments where traffic is switched instantly between versions.

### Blue-Green Features

- **Separate Active/Preview Environments**: Different replica counts for cost efficiency
- **Dual Service Architecture**: Independent services for active and preview
- **Split Ingress Configuration**: Separate URLs and configurations for each environment
- **Instant Traffic Switch**: 100% traffic cutover with rollback capability
- **Manual or Automated Promotion**: Control when to switch traffic
- **Built-in Analysis**: Pre and post-promotion validation
- **Cost Optimization**: Preview runs with fewer replicas

### Basic Blue-Green Configuration

```yaml
businessLabels:
  bu: "platform"
  project: "ecommerce"
  application: "api"
  env: "production"

workload:
  type: rollout
  rollout:
    enabled: true
    replicas: 5  # Active environment replica count
    revisionHistoryLimit: 5
    strategy:
      blueGreen:
        # Service names for blue-green
        activeService: ecommerce-api-active
        previewService: ecommerce-api-preview
        
        # Preview environment settings
        previewReplicaCount: 2  # Cost-effective preview size
        scaleDownDelaySeconds: 30
        autoPromotionEnabled: false  # Manual approval required
        
        # Analysis configuration
        prePromotionAnalysis:
          templates:
          - templateName: success-rate
          args:
          - name: service-name
            value: ecommerce-api-preview
        
        postPromotionAnalysis:
          templates:
          - templateName: success-rate
          args:
          - name: service-name
            value: ecommerce-api-active

# Separate services for active and preview
services:
  active:
    enabled: true
    type: ClusterIP
    port: 80
    targetPort: 8080
    labels:
      service-type: "active"
      traffic-type: "production"
  
  preview:
    enabled: true
    type: ClusterIP
    port: 80
    targetPort: 8080
    labels:
      service-type: "preview"
      traffic-type: "testing"
```

### Blue-Green Ingress Configuration

```yaml
ingress:
  # Environment-specific labels
  labels_active:
    environment: "production"
    traffic-split: "active"
  labels_preview:
    environment: "preview"
    traffic-split: "preview"
    
  # Environment-specific annotations
  annotations_active:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    
  annotations_preview:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
    nginx.ingress.kubernetes.io/auth-type: "basic"
    nginx.ingress.kubernetes.io/auth-secret: "preview-auth"
  
  data:
    api:
      enabled: true
      className: "nginx"
      hosts:
        - host: api.mycompany.com           # Production URL
          host_preview: preview-api.mycompany.com  # Preview URL
          paths:
            - path: /api/v1
              pathType: Prefix
              servicePort: 80
      
      # Separate TLS for each environment
      tls:
        - secretName: api-prod-tls
          hosts: [api.mycompany.com]
      tls_preview:
        - secretName: api-preview-tls
          hosts: [preview-api.mycompany.com]

# Authentication for preview access
secrets:
  preview-auth:
    enabled: true
    type: Opaque
    stringData:
      auth: "preview:$2y$10$..."  # htpasswd generated
```

### Blue-Green Deployment Flow

1. **Initial Deployment**
   ```bash
   helm install my-app ./chart -f bluegreen-values.yaml
   ```
   - Creates active environment with 5 replicas
   - Sets up production ingress at `api.mycompany.com`

2. **Deploy New Version**
   ```bash
   helm upgrade my-app ./chart -f bluegreen-values.yaml \
     --set image.tag=v2.0.0
   ```
   - Creates preview environment with 2 replicas
   - Makes preview available at `preview-api.mycompany.com`
   - Active continues serving production traffic

3. **Test Preview Environment**
   ```bash
   # Test the preview version
   curl -H "Authorization: Basic <credentials>" \
     https://preview-api.mycompany.com/api/v1/health
   ```

4. **Promote to Production**
   ```bash
   # Manual promotion
   kubectl argo rollouts promote my-app
   ```
   - Preview becomes new active (scales to 5 replicas)
   - Traffic switches to new version instantly
   - Old version scales down after delay

## 🟡 Canary Deployment Strategy

Canary deployment gradually shifts traffic from the stable version to the new version, allowing for controlled rollouts and immediate rollback if issues arise.

### Canary Features

- **Gradual Traffic Shifting**: Progressive rollout with configurable traffic percentages
- **Single Service Architecture**: Uses traffic splitting with one service
- **Analysis-Driven Promotion**: Automatic promotion based on success metrics
- **Pause Points**: Manual gates for validation at each step
- **Immediate Rollback**: Quick revert to stable version
- **Header-Based Routing**: Route specific users to canary version

### Basic Canary Configuration

```yaml
businessLabels:
  bu: "platform"
  project: "ecommerce"
  application: "api"
  env: "production"

workload:
  type: rollout
  rollout:
    enabled: true
    replicas: 10  # Total replica count
    revisionHistoryLimit: 5
    strategy:
      canary:
        # Traffic management
        canaryService: ecommerce-api-canary  # Optional: separate canary service
        stableService: ecommerce-api-stable  # Main production service
        
        # Traffic splitting steps
        steps:
        - setWeight: 10    # 10% traffic to canary
        - pause: {}        # Manual gate
        
        - setWeight: 25    # 25% traffic to canary
        - pause:
            duration: 60   # Auto-advance after 1 minute
            
        - setWeight: 50    # 50% traffic to canary
        - pause: {}        # Manual gate
        
        - setWeight: 75    # 75% traffic to canary
        - pause:
            duration: 30
            
        # Final promotion happens automatically
        
        # Analysis at each step
        analysis:
          templates:
          - templateName: success-rate
          - templateName: latency-p99
          args:
          - name: service-name
            value: ecommerce-api
          
        # Rollback triggers
        abortScaleDownDelaySeconds: 30
        maxSurge: "25%"
        maxUnavailable: 1

# Single service for canary (traffic splitting handled by rollout)
services:
  main:
    enabled: true
    type: ClusterIP
    port: 80
    targetPort: 8080
    labels:
      service-type: "main"
  
  # Optional: Separate canary service for testing
  canary:
    enabled: true
    type: ClusterIP
    port: 80
    targetPort: 8080
    labels:
      service-type: "canary"
```

### Canary with Ingress Traffic Splitting

```yaml
ingress:
  annotations:
    kubernetes.io/ingress.class: "nginx"
    # Argo Rollouts will manage these annotations automatically
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "0"  # Managed by rollout
    
  data:
    api:
      enabled: true
      className: "nginx"
      hosts:
        - host: api.mycompany.com
          paths:
            - path: /api/v1
              pathType: Prefix
              servicePort: 80
      
      tls:
        - secretName: api-prod-tls
          hosts: [api.mycompany.com]
```

### Advanced Canary with Header-Based Routing

```yaml
workload:
  rollout:
    strategy:
      canary:
        # Header-based canary routing
        canaryMetadata:
          labels:
            role: canary
        stableMetadata:
          labels:
            role: stable
            
        # Traffic routing rules
        trafficRouting:
          nginx:
            stableIngress: ecommerce-api-stable
            annotationPrefix: nginx.ingress.kubernetes.io
            additionalIngressAnnotations:
              canary-by-header: "X-Canary"
              canary-by-header-value: "true"
            
        steps:
        - setHeaderRoute:
            name: "X-Canary"
            match:
            - headerName: "X-Canary"
              headerValue:
                exact: "true"
        - pause: {}
        
        - setWeight: 10
        - pause: {duration: 120}
        
        - setWeight: 50
        - pause: {}
```

### Canary Deployment Flow

1. **Initial Deployment**
   ```bash
   helm install my-app ./chart -f canary-values.yaml
   ```
   - Creates stable environment with 10 replicas
   - Sets up production ingress

2. **Deploy Canary Version**
   ```bash
   helm upgrade my-app ./chart -f canary-values.yaml \
     --set image.tag=v2.0.0
   ```
   - Starts canary deployment
   - 10% of traffic goes to new version
   - 90% continues to stable version

3. **Monitor and Promote**
   ```bash
   # Check rollout progress
   kubectl argo rollouts get rollout my-app --watch
   
   # Manual promotion at pause points
   kubectl argo rollouts promote my-app
   
   # Abort if issues detected
   kubectl argo rollouts abort my-app
   ```

## 🔄 Strategy Comparison

| Feature | Blue-Green | Canary |
|---------|------------|--------|
| **Traffic Switch** | Instant (0% → 100%) | Gradual (0% → 10% → 25% → 100%) |
| **Resource Usage** | Higher (2x during switch) | Lower (gradual scale) |
| **Rollback Speed** | Instant | Instant |
| **Risk Level** | Medium (full switch) | Low (gradual exposure) |
| **Testing** | Full preview environment | Production traffic testing |
| **Cost** | Higher (dual environments) | Lower (shared resources) |
| **Complexity** | Medium | Higher (traffic management) |

## 🎯 Advanced Analysis Templates

Both strategies support sophisticated analysis for automated decision making:

```yaml
# Success rate analysis template
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    successCondition: result[0] >= 0.95
    interval: 30s
    count: 5
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(
            http_requests_total{service="{{args.service-name}}",status!~"5.."}[2m]
          )) /
          sum(rate(
            http_requests_total{service="{{args.service-name}}"}[2m]
          ))

# Latency analysis template  
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: latency-p99
spec:
  args:
  - name: service-name
  metrics:
  - name: latency-p99
    successCondition: result[0] <= 0.5
    interval: 30s
    count: 5
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          histogram_quantile(0.99,
            sum(rate(http_request_duration_seconds_bucket{service="{{args.service-name}}"}[2m])) by (le)
          )
```

## 🛠️ Rollout Management Commands

```bash
# Watch rollout progress
kubectl argo rollouts get rollout my-app --watch

# Promote to next step
kubectl argo rollouts promote my-app

# Abort rollout
kubectl argo rollouts abort my-app

# Retry rollout
kubectl argo rollouts retry rollout my-app

# Rollback to previous version
kubectl argo rollouts undo my-app

# Set image (trigger new rollout)
kubectl argo rollouts set image my-app app=my-app:v2.0.0

# Pause rollout
kubectl argo rollouts pause my-app

# Resume rollout
kubectl argo rollouts resume my-app
```

## 🌐 Advanced Ingress with Active/Preview Support

The chart supports creating separate ingresses for active and preview environments:

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

## 🚀 Quick Start Examples

### 1. Basic Deployment with Environment Variables

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

# These will be loaded as environment variables
secrets:
  app-secrets:
    enabled: true
    stringData:
      DATABASE_URL: "postgresql://db:5432/myapp"
      JWT_SECRET: "super-secret-jwt-key"

configMaps:
  app-config:
    enabled: true
    data:
      LOG_LEVEL: "info"
      DEBUG: "false"

services:
  api:
    enabled: true
    port: 80
    targetPort: 8080
```

### 2. Advanced Deployment with Volume Mounts

```yaml
businessLabels:
  bu: "platform"
  project: "ecommerce"
  application: "api"
  env: "production"

workload:
  type: deployment
  deployment:
    replicas: 5

# SSL certificates mounted as files
secrets:
  ssl-certs:
    enabled: true
    type: kubernetes.io/tls
    mountPath: /etc/ssl/certs
    defaultMode: 0400
    data:
      tls.crt: LS0tLS1CRUdJTi...
      tls.key: LS0tLS1CRUdJTi...

# App config as environment variables
secrets:
  app-secrets:
    enabled: true
    stringData:
      DATABASE_URL: "postgresql://db:5432/ecommerce"
      REDIS_URL: "redis://redis:6379"

# Nginx config mounted as files
configMaps:
  nginx-config:
    enabled: true
    mountPath: /etc/nginx/conf.d
    data:
      default.conf: |
        server {
          listen 443 ssl;
          ssl_certificate /etc/ssl/certs/tls.crt;
          ssl_certificate_key /etc/ssl/certs/tls.key;
          
          location / {
            proxy_pass http://localhost:8080;
          }
        }

# External secrets from AWS
externalSecrets:
  enabled: true
  name: "aws-secret-store"
  cloud: "aws"
  es:
    database-creds:
      data:
        username:
          key: "prod/database"
          property: "username"
        password:
          key: "prod/database"
          property: "password"
```

### 3. Job with Mixed Configuration Sources

```yaml
businessLabels:
  bu: "data"
  project: "analytics"
  application: "etl"
  env: "production"

jobs:
  data-migration:
    enabled: true
    backoffLimit: 3
    restartPolicy: Never
    image:
      repository: my-company/etl
      tag: "v2.0"
    command: ["python", "migrate.py"]

# Database credentials as environment variables
secrets:
  db-creds:
    enabled: true
    stringData:
      DB_HOST: "postgres.prod.internal"
      DB_USER: "etl_user"
      DB_PASSWORD: "secret-password"

# Migration scripts mounted as files
configMaps:
  migration-scripts:
    enabled: true
    mountPath: /app/migrations
    data:
      001_initial_schema.sql: |
        CREATE TABLE users (
          id SERIAL PRIMARY KEY,
          name VARCHAR(255) NOT NULL
        );
      002_add_indexes.sql: |
        CREATE INDEX idx_users_name ON users(name);

# SSL client certificate for secure DB connection
secrets:
  db-ssl-cert:
    enabled: true
    mountPath: /etc/ssl/db
    defaultMode: 0400
    data:
      client.crt: LS0tLS1CRUdJTi...
      client.key: LS0tLS1CRUdJTi...
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
   - Ensure secrets/configmaps without `mountPath` are being created

2. **Volume Mounts Not Working**
   - Verify `mountPath` is specified for the resource
   - Check file permissions with `defaultMode`
   - Ensure the secret/configmap is enabled

3. **External Secrets Not Mounting**
   - Verify External Secrets Operator is installed
   - Check SecretStore configuration
   - Ensure `mountPath` is specified for volume mounting

4. **Permission Issues with Mounted Files**
   - Use `defaultMode` to set overall permissions
   - Use `items` with specific `mode` for individual files
   - Consider using `0400` for sensitive files like private keys

5. **Mixed Environment Variables and Volume Mounts**
   - Resources without `mountPath` → environment variables
   - Resources with `mountPath` → volume mounts
   - You can have multiple resources of the same type with different behaviors

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
# For sensitive files, use restrictive permissions
secrets:
  private-keys:
    enabled: true
    mountPath: /etc/ssl/private
    defaultMode: 0400  # Read-only for owner only
    readOnly: true
    items:
      - key: server.key
        path: server.key
        mode: 0400
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

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test with different workload combinations
4. Test the new `mountPath` functionality
5. Update documentation
6. Submit a pull request
