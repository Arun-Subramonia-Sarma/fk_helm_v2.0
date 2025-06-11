{{/*
Expand the name of the chart.
*/}}
{{- define "generic-chart.name" -}}
{{- default .Chart.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "generic-chart.fullname" -}}
{{- if .Values.global.fullnameOverride }}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.global.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "generic-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Business labels - Applied to all resources
Dynamically iterates over all key-value pairs in businessLabels
*/}}
{{- define "generic-chart.businessLabels" -}}
{{- range $key, $value := .Values.businessLabels }}
{{- if $value }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels - Includes business labels and Helm standard labels
*/}}
{{- define "generic-chart.labels" -}}
helm.sh/chart: {{ include "generic-chart.chart" . }}
{{ include "generic-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- include "generic-chart.businessLabels" . | nindent 0 }}
{{- end }}

{{/*
Selector labels - Used for pod selectors (includes business labels for consistency)
*/}}
{{- define "generic-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "generic-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- include "generic-chart.businessLabels" . | nindent 0 }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "generic-chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "generic-chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
CONSOLIDATED LABEL AND ANNOTATION MERGING HELPERS
These helpers merge multiple label/annotation dictionaries with deduplication
Usage: {{ include "generic-chart.mergeLabels" (list $labels1 $labels2 $labels3) }}
*/}}
{{- define "generic-chart.mergeLabels" -}}
{{- $merged := dict -}}
{{- range . -}}
  {{- if . -}}
    {{- range $key, $value := . -}}
      {{- $_ := set $merged $key $value -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if $merged -}}
{{- toYaml $merged -}}
{{- end -}}
{{- end }}

{{/*
Merge annotations helper - Merges multiple annotation dictionaries
Usage: {{ include "generic-chart.mergeAnnotations" (list $annotations1 $annotations2) }}
*/}}
{{- define "generic-chart.mergeAnnotations" -}}
{{- $merged := dict -}}
{{- range . -}}
  {{- if . -}}
    {{- range $key, $value := . -}}
      {{- $_ := set $merged $key $value -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if $merged -}}
{{- toYaml $merged -}}
{{- end -}}
{{- end }}

{{/*
VOLUME AND MOUNT HELPERS
Generate volumes from secrets, configmaps, and external secrets that have mountPath
*/}}
{{- define "generic-chart.autoVolumes" -}}
{{- $globalConfig := .globalConfig }}
{{- $volumes := list }}

{{/* Add volumes from secrets with mountPath */}}
{{- if $globalConfig.Values.secrets }}
{{- range $secretName, $secretConfig := $globalConfig.Values.secrets }}
{{- if and $secretConfig.enabled $secretConfig.mountPath }}
{{- $volume := dict 
    "name" (printf "secret-%s" $secretName)
    "secret" (dict 
      "secretName" (printf "%s-%s" (include "generic-chart.fullname" $globalConfig) $secretName)
      "defaultMode" ($secretConfig.defaultMode | default 420)
    )
}}
{{- if $secretConfig.items }}
{{- $_ := set $volume.secret "items" $secretConfig.items }}
{{- end }}
{{- $volumes = append $volumes $volume }}
{{- end }}
{{- end }}
{{- end }}

{{/* Add volumes from configmaps with mountPath */}}
{{- if $globalConfig.Values.configMaps }}
{{- range $configMapName, $configMapConfig := $globalConfig.Values.configMaps }}
{{- if and $configMapConfig.enabled $configMapConfig.mountPath }}
{{- $volume := dict 
    "name" (printf "configmap-%s" $configMapName)
    "configMap" (dict 
      "name" (printf "%s-%s" (include "generic-chart.fullname" $globalConfig) $configMapName)
      "defaultMode" ($configMapConfig.defaultMode | default 420)
    )
}}
{{- if $configMapConfig.items }}
{{- $_ := set $volume.configMap "items" $configMapConfig.items }}
{{- end }}
{{- $volumes = append $volumes $volume }}
{{- end }}
{{- end }}
{{- end }}

{{/* Add volumes from external secrets with mountPath */}}
{{- if and $globalConfig.Values.externalSecrets $globalConfig.Values.externalSecrets.enabled $globalConfig.Values.externalSecrets.es }}
{{- range $externalSecretName, $externalSecretConfig := $globalConfig.Values.externalSecrets.es }}
{{- if $externalSecretConfig.mountPath }}
{{- $volume := dict 
    "name" (printf "external-secret-%s" $externalSecretName)
    "secret" (dict 
      "secretName" (printf "%s-%s" (include "generic-chart.fullname" $globalConfig) $externalSecretName)
      "defaultMode" ($externalSecretConfig.defaultMode | default 420)
    )
}}
{{- if $externalSecretConfig.items }}
{{- $_ := set $volume.secret "items" $externalSecretConfig.items }}
{{- end }}
{{- $volumes = append $volumes $volume }}
{{- end }}
{{- end }}
{{- end }}

{{- toYaml $volumes }}
{{- end }}

{{/*
Generate volume mounts from secrets, configmaps, and external secrets that have mountPath
*/}}
{{- define "generic-chart.autoVolumeMounts" -}}
{{- $globalConfig := .globalConfig }}
{{- $volumeMounts := list }}

{{/* Add volume mounts from secrets with mountPath */}}
{{- if $globalConfig.Values.secrets }}
{{- range $secretName, $secretConfig := $globalConfig.Values.secrets }}
{{- if and $secretConfig.enabled $secretConfig.mountPath }}
{{- $volumeMount := dict 
    "name" (printf "secret-%s" $secretName)
    "mountPath" $secretConfig.mountPath
    "readOnly" ($secretConfig.readOnly | default true)
}}
{{- if $secretConfig.subPath }}
{{- $_ := set $volumeMount "subPath" $secretConfig.subPath }}
{{- end }}
{{- $volumeMounts = append $volumeMounts $volumeMount }}
{{- end }}
{{- end }}
{{- end }}

{{/* Add volume mounts from configmaps with mountPath */}}
{{- if $globalConfig.Values.configMaps }}
{{- range $configMapName, $configMapConfig := $globalConfig.Values.configMaps }}
{{- if and $configMapConfig.enabled $configMapConfig.mountPath }}
{{- $volumeMount := dict 
    "name" (printf "configmap-%s" $configMapName)
    "mountPath" $configMapConfig.mountPath
    "readOnly" ($configMapConfig.readOnly | default true)
}}
{{- if $configMapConfig.subPath }}
{{- $_ := set $volumeMount "subPath" $configMapConfig.subPath }}
{{- end }}
{{- $volumeMounts = append $volumeMounts $volumeMount }}
{{- end }}
{{- end }}
{{- end }}

{{/* Add volume mounts from external secrets with mountPath */}}
{{- if and $globalConfig.Values.externalSecrets $globalConfig.Values.externalSecrets.enabled $globalConfig.Values.externalSecrets.es }}
{{- range $externalSecretName, $externalSecretConfig := $globalConfig.Values.externalSecrets.es }}
{{- if $externalSecretConfig.mountPath }}
{{- $volumeMount := dict 
    "name" (printf "external-secret-%s" $externalSecretName)
    "mountPath" $externalSecretConfig.mountPath
    "readOnly" ($externalSecretConfig.readOnly | default true)
}}
{{- if $externalSecretConfig.subPath }}
{{- $_ := set $volumeMount "subPath" $externalSecretConfig.subPath }}
{{- end }}
{{- $volumeMounts = append $volumeMounts $volumeMount }}
{{- end }}
{{- end }}
{{- end }}

{{- toYaml $volumeMounts }}
{{- end }}

{{/*
ENVIRONMENT VARIABLE HELPERS
Generate envFrom for secrets and configmaps that do NOT have mountPath
*/}}
{{- define "generic-chart.autoEnvFrom" -}}
{{- $globalConfig := .globalConfig }}
{{- $envFrom := list }}

{{/* Add envFrom for secrets without mountPath */}}
{{- if $globalConfig.Values.secrets }}
{{- range $secretName, $secretConfig := $globalConfig.Values.secrets }}
{{- if and $secretConfig.enabled (not $secretConfig.mountPath) }}
{{- $envFrom = append $envFrom (dict 
    "secretRef" (dict 
      "name" (printf "%s-%s" (include "generic-chart.fullname" $globalConfig) $secretName)
    )
) }}
{{- end }}
{{- end }}
{{- end }}

{{/* Add envFrom for configmaps without mountPath */}}
{{- if $globalConfig.Values.configMaps }}
{{- range $configMapName, $configMapConfig := $globalConfig.Values.configMaps }}
{{- if and $configMapConfig.enabled (not $configMapConfig.mountPath) }}
{{- $envFrom = append $envFrom (dict 
    "configMapRef" (dict 
      "name" (printf "%s-%s" (include "generic-chart.fullname" $globalConfig) $configMapName)
    )
) }}
{{- end }}
{{- end }}
{{- end }}

{{/* Add envFrom for external secrets without mountPath */}}
{{- if and $globalConfig.Values.externalSecrets $globalConfig.Values.externalSecrets.enabled $globalConfig.Values.externalSecrets.es }}
{{- range $externalSecretName, $externalSecretConfig := $globalConfig.Values.externalSecrets.es }}
{{- if not $externalSecretConfig.mountPath }}
{{- $envFrom = append $envFrom (dict 
    "secretRef" (dict 
      "name" (printf "%s-%s" (include "generic-chart.fullname" $globalConfig) $externalSecretName)
    )
) }}
{{- end }}
{{- end }}
{{- end }}

{{- toYaml $envFrom }}
{{- end }}

{{/*
Merge environment variables from different sources
*/}}
{{- define "generic-chart.mergedEnvVars" -}}
{{- $globalConfig := .globalConfig }}
{{- $containerConfig := .containerConfig }}
{{- $envList := list }}

{{/* Add global envVars (key=value format) */}}
{{- if $globalConfig.Values.envVars }}
{{- range $key, $value := $globalConfig.Values.envVars }}
{{- $envList = append $envList (dict "name" $key "value" ($value | toString)) }}
{{- end }}
{{- end }}

{{/* Add container-specific envVars (key=value format) */}}
{{- if $containerConfig.envVars }}
{{- range $key, $value := $containerConfig.envVars }}
{{- $envList = append $envList (dict "name" $key "value" ($value | toString)) }}
{{- end }}
{{- end }}

{{/* Add global envValueFrom */}}
{{- if $globalConfig.Values.envValueFrom }}
{{- range $key, $valueFrom := $globalConfig.Values.envValueFrom }}
{{- $envList = append $envList (dict "name" $key "valueFrom" $valueFrom) }}
{{- end }}
{{- end }}

{{/* Add container-specific envValueFrom */}}
{{- if $containerConfig.envValueFrom }}
{{- range $key, $valueFrom := $containerConfig.envValueFrom }}
{{- $envList = append $envList (dict "name" $key "valueFrom" $valueFrom) }}
{{- end }}
{{- end }}

{{/* Add traditional env arrays */}}
{{- if $globalConfig.Values.env }}
{{- $envList = concat $envList $globalConfig.Values.env }}
{{- end }}

{{- if $containerConfig.env }}
{{- $envList = concat $envList $containerConfig.env }}
{{- end }}

{{- toYaml $envList }}
{{- end }}

{{/*
POD TEMPLATE HELPERS
Universal Pod Template - Used by all workload types with robust error handling
*/}}
{{- define "generic-chart.podTemplate" -}}
{{- $globalConfig := .globalConfig -}}
{{- $podConfig := .podConfig | default dict -}}

{{/* Safe image construction */}}
{{- $imageName := "nginx:latest" -}}
{{- if and $podConfig.image $podConfig.image.repository $podConfig.image.tag -}}
  {{- $imageName = printf "%s:%s" $podConfig.image.repository $podConfig.image.tag -}}
{{- else if and $globalConfig.Values.image $globalConfig.Values.image.repository $globalConfig.Values.image.tag -}}
  {{- $imageName = printf "%s:%s" $globalConfig.Values.image.repository $globalConfig.Values.image.tag -}}
{{- end -}}

{{/* Initialize envFrom variables safely */}}
{{- $envFromVars := list -}}
{{- $autoEnvFrom := list -}}

{{/* Process envFrom configurations */}}
{{- if $podConfig.envFrom -}}
  {{- if kindIs "slice" $podConfig.envFrom -}}
    {{- $envFromVars = $podConfig.envFrom -}}
  {{- else if kindIs "map" $podConfig.envFrom -}}
    {{- range $key, $value := $podConfig.envFrom -}}
      {{- if kindIs "map" $value -}}
        {{- $envFromVars = append $envFromVars $value -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/* Process auto envFrom configurations */}}
{{- if and $globalConfig.Values $globalConfig.Values.autoEnvFrom -}}
  {{- if kindIs "slice" $globalConfig.Values.autoEnvFrom -}}
    {{- $autoEnvFrom = $globalConfig.Values.autoEnvFrom -}}
  {{- else if kindIs "map" $globalConfig.Values.autoEnvFrom -}}
    {{- range $key, $value := $globalConfig.Values.autoEnvFrom -}}
      {{- if kindIs "map" $value -}}
        {{- $autoEnvFrom = append $autoEnvFrom $value -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/* Combine envFrom lists safely */}}
{{- $combinedEnvFrom := list -}}
{{- if $envFromVars -}}
  {{- $combinedEnvFrom = $envFromVars -}}
{{- end -}}
{{- if $autoEnvFrom -}}
  {{- $combinedEnvFrom = concat $combinedEnvFrom $autoEnvFrom -}}
{{- end -}}

spec:
  {{- if or $podConfig.serviceAccountName $globalConfig.Values.serviceAccountName }}
  serviceAccountName: {{ $podConfig.serviceAccountName | default $globalConfig.Values.serviceAccountName }}
  {{- end }}
  
  {{- with ($podConfig.securityContext | default $globalConfig.Values.securityContext) }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  
  {{- with ($podConfig.nodeSelector | default $globalConfig.Values.nodeSelector) }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  
  {{- with ($podConfig.tolerations | default $globalConfig.Values.tolerations) }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  
  {{- with ($podConfig.affinity | default $globalConfig.Values.affinity) }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  
  {{- if or $podConfig.restartPolicy $globalConfig.Values.restartPolicy }}
  restartPolicy: {{ $podConfig.restartPolicy | default $globalConfig.Values.restartPolicy | default "Always" }}
  {{- end }}
  
  containers:
  - name: {{ $podConfig.name | default $globalConfig.Values.containerName | default "main" }}
    image: {{ $imageName }}
    imagePullPolicy: {{ ($podConfig.image).pullPolicy | default ($globalConfig.Values.image).pullPolicy | default "IfNotPresent" }}
    
    {{- with ($podConfig.ports | default $globalConfig.Values.ports) }}
    ports:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    
    {{- with ($podConfig.env | default $globalConfig.Values.env) }}
    env:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    
    {{- if $combinedEnvFrom }}
    envFrom:
      {{- toYaml $combinedEnvFrom | nindent 6 }}
    {{- end }}
    
    {{- with ($podConfig.resources | default $globalConfig.Values.resources) }}
    resources:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    
    {{- with ($podConfig.volumeMounts | default $globalConfig.Values.volumeMounts) }}
    volumeMounts:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    
    {{- with ($podConfig.livenessProbe | default $globalConfig.Values.livenessProbe) }}
    livenessProbe:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    
    {{- with ($podConfig.readinessProbe | default $globalConfig.Values.readinessProbe) }}
    readinessProbe:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    
    {{- with ($podConfig.command | default $globalConfig.Values.command) }}
    command:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    
    {{- with ($podConfig.args | default $globalConfig.Values.args) }}
    args:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  
  {{- with ($podConfig.volumes | default $globalConfig.Values.volumes) }}
  volumes:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  
  {{- with ($podConfig.imagePullSecrets | default $globalConfig.Values.imagePullSecrets) }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

{{/*
UTILITY HELPERS
Helper to get image safely
*/}}
{{- define "generic-chart.getImage" -}}
{{- $podConfig := .podConfig -}}
{{- $globalConfig := .globalConfig -}}

{{- if and $podConfig.image $podConfig.image.repository $podConfig.image.tag -}}
{{- printf "%s:%s" $podConfig.image.repository $podConfig.image.tag -}}
{{- else if and $globalConfig.Values.image $globalConfig.Values.image.repository $globalConfig.Values.image.tag -}}
{{- printf "%s:%s" $globalConfig.Values.image.repository $globalConfig.Values.image.tag -}}
{{- else -}}
nginx:latest
{{- end -}}
{{- end }}

{{/*
Helper to validate required values
*/}}
{{- define "generic-chart.validateConfig" -}}
{{- $globalConfig := .globalConfig -}}
{{- $podConfig := .podConfig -}}

{{- if not (or ($podConfig.image.repository) ($globalConfig.Values.image.repository)) -}}
{{- fail "ERROR: image.repository is required in either podConfig or global Values" -}}
{{- end -}}

{{- if not (or ($podConfig.image.tag) ($globalConfig.Values.image.tag)) -}}
{{- fail "ERROR: image.tag is required in either podConfig or global Values" -}}
{{- end -}}
{{- end }}