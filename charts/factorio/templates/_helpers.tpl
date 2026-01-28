{{/*
Convert camelCase keys to snake_case for Factorio server-settings.json
Usage: {{ include "factorio.camelToSnake" .Values.gameConfig.serverSettings | fromYaml | toJson }}
*/}}
{{- define "factorio.camelToSnake" -}}
{{- $result := dict -}}
{{- range $key, $value := . -}}
  {{- $snakeKey := $key -}}
  {{- /* Convert camelCase to snake_case */ -}}
  {{- $snakeKey = regexReplaceAll "([a-z0-9])([A-Z])" $snakeKey "${1}_${2}" | lower -}}
  {{- /* Handle nested maps recursively */ -}}
  {{- if kindIs "map" $value -}}
    {{- $_ := set $result $snakeKey (include "factorio.camelToSnake" $value | fromYaml) -}}
  {{- else if kindIs "slice" $value -}}
    {{- $_ := set $result $snakeKey $value -}}
  {{- else -}}
    {{- $_ := set $result $snakeKey $value -}}
  {{- end -}}
{{- end -}}
{{- $result | toYaml -}}
{{- end -}}
