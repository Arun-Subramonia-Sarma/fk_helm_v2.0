# FourKites Helm Chart - Fixed Duplicate Labels Issue

This is the corrected version of the Helm chart that resolves the duplicate business labels issue found in sample11.

## Problem Fixed

The original chart in sample11 had duplicate business labels appearing in both:
1. Workload metadata labels (via `generic-chart.labels` template)
2. Selector labels (via `generic-chart.selectorLabels` template)

This caused business labels to be duplicated in the generated Kubernetes resources.

## Solution Applied

Modified the `generic-chart.selectorLabels` template in `templates/_templates.tpl` to:
- Remove business labels from selector labels
- Keep only minimal and stable labels for selectors:
  - `app.kubernetes.io/name`
  - `app.kubernetes.io/instance`

## Changes Made

### Before (sample11):
```yaml
{{/*
Selector labels - Used for pod selectors (includes business labels for consistency)
*/}}
{{- define "generic-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "generic-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- include "generic-chart.businessLabels" . | nindent 0 }}
{{- end }}
```

### After (sample12):
```yaml
{{/*
Selector labels - Used for pod selectors (minimal and stable labels only)
*/}}
{{- define "generic-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "generic-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

## Benefits

1. **No Duplicate Labels**: Business labels now appear only once in workload metadata
2. **Kubernetes Best Practices**: Selector labels are minimal and stable
3. **Cleaner Resources**: Generated Kubernetes resources have proper label structure
4. **Backward Compatible**: No breaking changes to existing functionality

## Label Structure After Fix

- **Workload Metadata Labels**: Include business labels, Helm standard labels, and workload-specific labels
- **Selector Labels**: Include only minimal stable labels for pod selection
- **Pod Labels**: Include selector labels plus additional pod-specific labels

This ensures business labels are present where needed without duplication.
