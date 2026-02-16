{{- define "nextcloud.redis.serviceName" -}}
{{- printf "%s-master" (include "common.names.fullname" .Subcharts.redis) -}}
{{- end -}}

{{- define "nextcloud.redis.auth.secretName" -}}
{{- default (include "common.names.fullname" .Subcharts.redis) .Values.redis.auth.existingSecret -}}
{{- end -}}

{{- define "nextcloud.redis.auth.passwordKey" -}}
{{- if .Values.redis.auth.existingSecret -}}
{{-   .Values.redis.auth.existingSecretPasswordKey -}}
{{- else -}}
{{-   "redis-password" -}}
{{- end -}}
{{- end -}}

{{- define "nextcloud.redis.env" -}}
{{- if .Values.redis.enabled }}
- name: REDIS_HOST
  value: {{ include "nextcloud.redis.serviceName" . }}
- name: REDIS_HOST_PORT
  value: {{ .Values.redis.master.service.ports.redis | quote }}
{{- if .Values.redis.auth.enabled }}
- name: REDIS_HOST_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "nextcloud.redis.auth.secretName" . }}
      key: {{ include "nextcloud.redis.auth.passwordKey" . }}
{{- end }}
{{- end }}
{{- end -}}