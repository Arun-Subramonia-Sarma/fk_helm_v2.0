# Sample14 - GlobalName from DictConfig

This sample builds upon Sample13 and ensures that the `globalName` parameter comes from the `dictConfig` instead of being hardcoded, providing better consistency and centralized naming control.

## Changes Made

### 1. Updated workloads.yaml

Modified all workload types (deployment, statefulset, daemonset, rollout) to use `globalName` from `dictConfig`:

**Before (Sample13):**
```yaml
{{- include "generic-chart.podTemplate" (dict "globalName" (include "generic-chart.fullname" .) "globalConfig" . "podConfig" $dictConfig.podConfig "containerConfig" $dictConfig.containerConfig) | nindent 4 }}
```

**After (Sample14):**
```yaml
{{- include "generic-chart.podTemplate" (dict "globalName" $dictConfig.containerConfig.name "globalConfig" . "podConfig" $dictConfig.podConfig "containerConfig" $dictConfig.containerConfig) | nindent 4 }}
```

### 2. Benefits

- **Centralized Naming**: The `globalName` now comes from the `dictConfig.containerConfig.name` which is set in the `generic-chart.workloadDictConfig` function
- **Consistency**: All workload types use the same naming source from the dictConfig
- **Single Source of Truth**: The name is defined once in the dictConfig and used consistently across all templates
- **Better Maintainability**: Changes to naming logic only need to be made in the dictConfig constructor

### 3. How it Works

1. The `generic-chart.workloadDictConfig` function in `_templates.tpl` sets:
   ```yaml
   {{- $_ := set $containerConfig "name" (include "generic-chart.fullname" $global) }}
   ```

2. Each workload type retrieves this name from the dictConfig:
   ```yaml
   {{- $dictConfig := include "generic-chart.workloadDictConfig" (dict "global" . "workloadType" "deployment") | fromYaml }}
   ```

3. The `globalName` parameter is passed as `$dictConfig.containerConfig.name` instead of recalculating it

### 4. Comparison with Previous Samples

**Sample12:** Basic dict construction with hardcoded empty dicts
**Sample13:** Introduced common dict constructor function
**Sample14:** Uses globalName from dictConfig for complete consistency

### 5. Usage

This ensures that all object naming is controlled through the dictConfig, making it easier to:
- Modify naming conventions in one place
- Ensure consistency across all workload types
- Maintain centralized control over resource naming

The `globalName` is now properly sourced from the dictConfig, ensuring that all Kubernetes objects use consistent naming derived from the centralized configuration.
