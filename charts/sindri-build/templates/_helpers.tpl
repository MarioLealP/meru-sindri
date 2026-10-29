{{/* The build namespace: <app>-build. */}}
{{- define "sindri-build.namespace" -}}
{{ required "app is required" .Values.app }}-build
{{- end }}

{{/* Meru's CMDB labels (compliance rule 7) - every resource and every pod carries them. */}}
{{- define "sindri-build.meruLabels" -}}
app.kubernetes.io/part-of: meru
meru.clockmost.com/app: {{ .Values.app }}
meru.clockmost.com/owner: {{ required "owner is required" .Values.owner }}
{{- end }}

{{- define "sindri-build.labels" -}}
{{ include "sindri-build.meruLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/* GITEA_RUNNER_LABELS: label:kubernetes://image, comma-separated (map order = sorted). */}}
{{- define "sindri-build.runnerLabels" -}}
{{- $labels := list -}}
{{- range $label, $image := .Values.labels -}}
{{- $labels = append $labels (printf "%s:kubernetes://%s" $label $image) -}}
{{- end -}}
{{ join "," $labels }}
{{- end }}
