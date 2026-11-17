{{/* The build namespace: <app>-build. */}}
{{- define "sindri-build.namespace" -}}
{{ required "app is required" .Values.app }}-build
{{- end }}

{{/* Meru's CMDB labels - every resource and every pod carries them. */}}
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
{{- if or $.Values.build (ne $label "sindri") -}}
{{- $labels = append $labels (printf "%s:kubernetes://%s" $label $image) -}}
{{- end -}}
{{- end -}}
{{ join "," $labels }}
{{- end }}

{{/* A CI job's cost against the node's build budget, in the pools' units (cm-jnxa). Refused when it is above a pool. */}}
{{- define "sindri-build.costMemory" -}}
{{- $m := .Values.buildCost.memory | toString -}}
{{- $mi := ternary (mul (trimSuffix "Gi" $m | int) 1024) (trimSuffix "Mi" $m | int) (hasSuffix "Gi" $m) -}}
{{- if gt $mi (int .Values.buildPool.memory) }}{{ fail (printf "buildCost.memory %s is above the node's build-memory pool (%d MiB)" $m (int .Values.buildPool.memory)) }}{{ end -}}
{{ $mi }}
{{- end }}

{{- define "sindri-build.costDisk" -}}
{{- $d := trimSuffix "Gi" (.Values.buildCost.disk | toString) | int -}}
{{- if gt $d (int .Values.buildPool.disk) }}{{ fail (printf "buildCost.disk %dGi is above the node's build-disk pool (%d GiB)" $d (int .Values.buildPool.disk)) }}{{ end -}}
{{ $d }}
{{- end }}

{{- define "sindri-build.costCpu" -}}
{{- $c := .Values.buildCost.cpu | toString -}}
{{- $m := ternary (trimSuffix "m" $c | int) (mul ($c | int) 1000) (hasSuffix "m" $c) -}}
{{- if gt $m (int .Values.buildPool.cpu) }}{{ fail (printf "buildCost.cpu %s is above the node's build-cpu pool (%dm)" $c (int .Values.buildPool.cpu)) }}{{ end -}}
{{ $m }}
{{- end }}

{{/* The build container's ephemeral-storage limit in GiB: 1.25x the disk cost, at least 3. */}}
{{- define "sindri-build.diskLimit" -}}
{{ max 3 (div (add (mul (include "sindri-build.costDisk" . | int) 5) 3) 4) }}
{{- end }}

