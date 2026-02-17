{{- define "nextcloud.fullname" -}}
{{- include "common.names.fullname" . -}}
{{- end -}}

{{- define "nextcloud.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "nextcloud.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.create -}}
{{- end -}}
{{- end -}}

{{- define "nextcloud.proxy.fullname" -}}
{{- printf "%s-proxy" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "nextcloud.proxy.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.proxy.image "global" .Values.global "chart" .Chart) -}}
{{- end -}}

{{- define "nextcloud.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.nextcloud.image "global" .Values.global "chart" .Chart) -}}
{{- end -}}

{{/*
Get the password secret.
*/}}
{{- define "nextcloud.auth.secretName" -}}
{{- if .Values.auth.existingSecret -}}
    {{- printf "%s" (tpl .Values.auth.existingSecret $) -}}
{{- else -}}
    {{- printf "%s" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Get the admin-username key.
*/}}
{{- define "nextcloud.auth.adminUsernameKey" -}}
{{- if and .Values.auth.existingSecret .Values.auth.secretKeys.adminUsernameKey -}}
  {{- printf "%s" (tpl .Values.auth.secretKeys.adminUsernameKey $) -}}
{{- else -}}
  {{- "username" -}}
{{- end -}}
{{- end -}}

{{/*
Get the admin-password key.
*/}}
{{- define "nextcloud.auth.adminPasswordKey" -}}
{{- if and .Values.auth.existingSecret .Values.auth.secretKeys.adminPasswordKey -}}
  {{- printf "%s" (tpl .Values.auth.secretKeys.adminPasswordKey $) -}}
{{- else -}}
  {{- "password" -}}
{{- end -}}
{{- end -}}

{{/*
Get the smtp-username key.
*/}}
{{- define "nextcloud.mail.smtpUsernameKey" -}}
{{- if and .Values.mail.existingSecret .Values.mail.secretKeys.smtpUsernameKey -}}
  {{- printf "%s" (tpl .Values.mail.secretKeys.smtpUsernameKey $) -}}
{{- else -}}
  {{- "username" -}}
{{- end -}}
{{- end -}}

{{/*
Get the smtp-password key.
*/}}
{{- define "nextcloud.mail.smtpPasswordKey" -}}
{{- if and .Values.mail.existingSecret .Values.mail.secretKeys.smtpPasswordKey -}}
  {{- printf "%s" (tpl .Values.mail.secretKeys.smtpPasswordKey $) -}}
{{- else -}}
  {{- "password" -}}
{{- end -}}
{{- end -}}

{{- define "nextcloud.env" -}}
- name: NEXTCLOUD_ADMIN_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "nextcloud.auth.secretName" . }}
      key: {{ include "nextcloud.auth.adminUsernameKey" . }}
- name: NEXTCLOUD_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "nextcloud.auth.secretName" . }}
      key: {{ include "nextcloud.auth.adminPasswordKey" . }}
- name: NEXTCLOUD_TRUSTED_DOMAINS
  {{- if .Values.nextcloud.trustedDomains }}
  value: {{ join " " .Values.nextcloud.trustedDomains | quote }}
  {{- else }}
  value: {{ .Values.nextcloud.host }} {{ template "common.names.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local
  {{- end }}
{{- if ne (int .Values.nextcloud.update) 0 }}
- name: NEXTCLOUD_UPDATE
  value: {{ .Values.nextcloud.update | quote }}
{{- end }}
- name: NEXTCLOUD_DATA_DIR
  value: {{ .Values.nextcloud.data.path | quote }}
- name: OVERWRITEPROTOCOL
  value: https
- name: OVERWRITEHOST
  value: {{ .Values.nextcloud.host }}
- name: TRUSTED_PROXIES
  value: {{ .Values.proxy.trustedIPs }}
{{- include "nextcloud.smtp.env" . }}
{{- include "nextcloud.redis.env" . }}
{{- include "nextcloud.postgresql.env" . }}
{{- if .Values.nextcloud.extraEnv }}
{{ toYaml .Values.nextcloud.extraEnv }}
{{- end }}
{{- end -}}

{{- define "nextcloud.tls.secretName" -}}
{{- if and .Values.ingress.tls.create (.Capabilities.APIVersions.Has "cert-manager.io/v1") -}}
{{-   printf "%s-tls" (include "nextcloud.fullname" .) -}}
{{- else -}}
{{-   .Values.ingress.tls.existingSecret -}}
{{- end -}}
{{- end -}}