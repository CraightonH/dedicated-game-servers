{{/*
Environment variables field for game server containers.
Supports both list and map formats.

List format (Kubernetes native):
  env:
    - name: SERVER_NAME
      value: "My Server"
    - name: SERVER_PORT
      value: "2456"

Map format (human-friendly):
  env:
    SERVER_NAME: "My Server"
    SERVER_PORT: 2456
    ADMIN_PASSWORD:
      value: "secret"
    DB_HOST:
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: host

Usage: {{ include "game-server.env" . }}
*/}}
{{- define "game-server.env" -}}
{{- $envValues := .Values.env -}}
{{- $envList := list -}}

{{- if not (empty $envValues) -}}
  {{- if kindIs "slice" $envValues -}}
    {{- /* Env is already a list - use as-is */ -}}
    {{- $envList = $envValues -}}
  {{- else if kindIs "map" $envValues -}}
    {{- /* Env is a map - convert to list format */ -}}
    {{- range $name, $value := $envValues -}}
      {{- $envItem := dict "name" $name -}}
      
      {{- if kindIs "map" $value -}}
        {{- /* Value is a map - merge it (supports value, valueFrom, etc.) */ -}}
        {{- $envItem = merge $envItem $value -}}
      {{- else -}}
        {{- /* Value is a scalar - set it directly */ -}}
        {{- $_ := set $envItem "value" ($value | toString) -}}
      {{- end -}}
      
      {{- $envList = append $envList $envItem -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- if not (empty $envList) -}}
  {{- toYaml $envList -}}
{{- end -}}
{{- end -}}
