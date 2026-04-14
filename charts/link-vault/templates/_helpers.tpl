{{/*
Expand the name of the chart.
*/}}
{{- define "link-vault.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated to 63 chars because Kubernetes name fields have this limit.
If fullnameOverride is set it takes priority (useful for predictable names
when deploying the same chart for multiple apps).
*/}}
{{- define "link-vault.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart label value: <chart-name>-<chart-version>
*/}}
{{- define "link-vault.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "link-vault.labels" -}}
helm.sh/chart: {{ include "link-vault.chart" . }}
{{ include "link-vault.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels — used by Deployment.spec.selector and Service.spec.selector.
Keep these stable; changing them requires deleting and recreating the Deployment.
*/}}
{{- define "link-vault.selectorLabels" -}}
app.kubernetes.io/name: {{ include "link-vault.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
