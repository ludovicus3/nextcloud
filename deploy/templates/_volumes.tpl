{{- define "nextcloud.persistence.claimName" -}}
{{- default (include "nextcloud.fullname" .) .Values.persistence.existingClaimName -}}
{{- end -}}

{{- define "nextcloud.persistence.data.claimName" -}}
{{- $default := printf "%s-data" (include "nextcloud.fullname" .) -}}
{{- default $default .Values.persistence.data.existingClaimName -}}
{{- end -}}

{{- define "nextcloud.volumes" -}}
{{- if .Values.persistence.enabled }}
- name: nextcloud
  persistentVolumeClaim:
    claimName: {{ include "nextcloud.persistence.claimName" . }}
{{- if .Values.persistence.data.enabled }}
- name: data
  persistentVolumeClaim:
    claimName: {{ include "nextcloud.persistence.data.claimName" . }}
{{- end }}
{{- else -}}
- name: nextcloud
  emptyDir: {}
{{- end }}
{{- end -}}

{{- define "nextcloud.volumeMounts" -}}
- name: nextcloud
  mountPath: /var/www/
  subPath: root
- name: nextcloud
  mountPath: /var/www/html
  subPath: html
{{- if .Values.persistence.data.enabled }}
- name: data
  mountPath: {{ .Values.nextcloud.data.path }}
  subPath: {{ default "data" .Values.persistence.data.subPath }}
{{- else }}
- name: nextcloud
  mountPath: {{ .Values.nextcloud.data.path }}
  subPath: data
{{- end }}
- name: nextcloud
  mountPath: /var/www/html/config
  subPath: config
- name: nextcloud
  mountPath: /var/www/html/custom_apps
  subPath: custom_apps
- name: nextcloud
  mountPath: /var/www/tmp
  subPath: tmp
- name: nextcloud
  mountPath: /var/www/html/themes
  subPath: themes
{{- end -}}