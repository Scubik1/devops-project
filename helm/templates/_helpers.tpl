{{/*
=================================================================
_helpers.tpl — вспомогательные шаблонные функции

Функции определённые здесь доступны во ВСЕХ шаблонах chart.
Вызываются через {{ include "devtracker.имяФункции" . }}

Принцип: DRY (Don't Repeat Yourself) — имена, лейблы и
селекторы определяются ОДИН РАЗ здесь и переиспользуются.
=================================================================
*/}}

{{/*----------------------------------------------------------------
  devtracker.name — базовое имя chart
----------------------------------------------------------------*/}}
{{- define "devtracker.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*----------------------------------------------------------------
  devtracker.fullname — полное имя релиза
  Используется как префикс для всех ресурсов.
  Пример: если release = "devtracker", chart = "devtracker"
  → результат: "devtracker"
----------------------------------------------------------------*/}}
{{- define "devtracker.fullname" -}}
{{- if .Values.fullnameOverride }}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
  {{- $name := .Chart.Name }}
  {{- if contains $name .Release.Name }}
    {{- .Release.Name | trunc 63 | trimSuffix "-" }}
  {{- else }}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
  {{- end }}
{{- end }}
{{- end }}

{{/*----------------------------------------------------------------
  devtracker.chart — имя и версия chart для лейблов
----------------------------------------------------------------*/}}
{{- define "devtracker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*----------------------------------------------------------------
  devtracker.commonLabels — лейблы для ВСЕХ ресурсов
  Эти лейблы помогают:
  - Фильтровать ресурсы: kubectl get all -l app.kubernetes.io/name=devtracker
  - Идентифицировать принадлежность к chart и релизу
  - Helm использует их для управления ресурсами
----------------------------------------------------------------*/}}
{{- define "devtracker.commonLabels" -}}
helm.sh/chart: {{ include "devtracker.chart" . }}
app.kubernetes.io/name: {{ include "devtracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*----------------------------------------------------------------
  devtracker.backendLabels — лейблы для backend ресурсов
----------------------------------------------------------------*/}}
{{- define "devtracker.backendLabels" -}}
{{ include "devtracker.commonLabels" . }}
app.kubernetes.io/component: backend
app: devtracker-backend
{{- end }}

{{/*----------------------------------------------------------------
  devtracker.backendSelectorLabels — лейблы для селекторов backend
  ВАЖНО: Селекторы нельзя изменять после создания Deployment!
  Поэтому они содержат только стабильные значения.
----------------------------------------------------------------*/}}
{{- define "devtracker.backendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "devtracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: backend
{{- end }}

{{/*----------------------------------------------------------------
  devtracker.frontendLabels — лейблы для frontend ресурсов
----------------------------------------------------------------*/}}
{{- define "devtracker.frontendLabels" -}}
{{ include "devtracker.commonLabels" . }}
app.kubernetes.io/component: frontend
app: devtracker-frontend
{{- end }}

{{/*----------------------------------------------------------------
  devtracker.frontendSelectorLabels — лейблы для селекторов frontend
----------------------------------------------------------------*/}}
{{- define "devtracker.frontendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "devtracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: frontend
{{- end }}

{{/*----------------------------------------------------------------
  devtracker.postgresLabels — лейблы для PostgreSQL ресурсов
----------------------------------------------------------------*/}}
{{- define "devtracker.postgresLabels" -}}
{{ include "devtracker.commonLabels" . }}
app.kubernetes.io/component: database
app: devtracker-postgres
{{- end }}

{{/*----------------------------------------------------------------
  devtracker.postgresSelectorLabels — лейблы для селекторов postgres
----------------------------------------------------------------*/}}
{{- define "devtracker.postgresSelectorLabels" -}}
app.kubernetes.io/name: {{ include "devtracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: database
{{- end }}

{{/*----------------------------------------------------------------
  devtracker.backendSecretName — имя Secret для backend
----------------------------------------------------------------*/}}
{{- define "devtracker.backendSecretName" -}}
{{- printf "%s-backend-secret" (include "devtracker.fullname" .) }}
{{- end }}

{{/*----------------------------------------------------------------
  devtracker.postgresSecretName — имя Secret для PostgreSQL
----------------------------------------------------------------*/}}
{{- define "devtracker.postgresSecretName" -}}
{{- printf "%s-postgres-secret" (include "devtracker.fullname" .) }}
{{- end }}
