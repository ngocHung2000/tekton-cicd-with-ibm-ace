{{/*
Expand the name of the chart.
*/}}
{{- define "ibm-ace.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ibm-ace.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ibm-ace.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
appconnect.ibm.com/kind: IntegrationRuntime
app.kubernetes.io/managed-by: ibm-appconnect
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ibm-ace.selectorLabels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
appconnect.ibm.com/kind: IntegrationRuntime
app.kubernetes.io/managed-by: ibm-appconnect
{{- end }}

