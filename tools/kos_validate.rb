#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8
ARGV.map! { |a| a.dup.force_encoding(Encoding::UTF_8) }

# kos_validate.rb — Valida la estructura de KOS. Sin red (salvo el chequeo opcional de PRs) y sin IA.
# Uso: ruby tools/kos_validate.rb [RAIZ]

require "yaml"
require "date"
require "pathname"
require "csv"
require "open3"

ROOT = Pathname.new(ARGV[0] || ".").expand_path
errors = []
warnings = []

def relative(path)
  path.relative_path_from(ROOT).to_s
rescue ArgumentError
  path.to_s
end

def add(list, code, file, message)
  list << { code: code, file: relative(file), message: message }
end

def load_yaml_file(path)
  YAML.load_file(path.to_s, permitted_classes: [Date, Time, Symbol], aliases: true)
rescue ArgumentError
  YAML.load_file(path.to_s)
end

def files_in(globs)
  Array(globs).flat_map { |g| Dir[ROOT.join(g).to_s] }.uniq.select { |p| File.file?(p) }.map { |p| Pathname.new(p) }
end

# --- Archivos críticos y configuración ---
%w[README.md AGENTS.md kos.yaml ONBOARDING/README.md knowledge/README.md registry/projects.yaml].each do |path|
  file = ROOT.join(path)
  if !file.file?
    add(errors, "required-file-missing", file, "Archivo crítico ausente")
  elsif file.read.strip.empty?
    add(errors, "required-file-empty", file, "Archivo crítico vacío")
  end
end

config = {}
begin
  config = load_yaml_file(ROOT.join("kos.yaml")) || {} if ROOT.join("kos.yaml").file?
rescue StandardError => e
  add(errors, "yaml-invalid", ROOT.join("kos.yaml"), e.message.lines.first.strip)
end
# Las claves de kos.yaml existen en español y en inglés.
checks = [config["chequeos"], config["checks"]].find { |c| c.is_a?(Hash) } || {}
installed = config["instalado"] == true || config["installed"] == true
pr_check = checks["github_prs"] == true
rows_check = checks.fetch("filas_de_listas", checks.fetch("list_rows", true)) != false

# --- YAML válido ---
yaml_files = files_in(["{projects,registry,templates,modules,i18n}/**/*.{yaml,yml}"])
yaml_files.each do |file|
  load_yaml_file(file)
rescue StandardError => e
  add(errors, "yaml-invalid", file, e.message.lines.first.strip)
end

# --- Registro, carpetas y manifiestos ---
registry_file = ROOT.join("registry/projects.yaml")
registry = begin
  registry_file.exist? ? load_yaml_file(registry_file) : nil
rescue StandardError
  nil
end
if !registry.is_a?(Hash) || !registry["projects"].is_a?(Array)
  add(errors, "registry-missing", registry_file, "No existe un registro de proyectos válido")
  registry = { "projects" => [] }
end
registry_ids = registry["projects"].map { |p| p["id"].to_s }
registry_ids.group_by(&:itself).select { |_id, v| v.size > 1 }.keys.each { |id| add(errors, "project-id-duplicate", registry_file, id) }
project_dirs = Dir[ROOT.join("projects/*").to_s].select { |p| File.directory?(p) }.map { |p| File.basename(p) }.reject { |p| p.start_with?(".") }
(registry_ids - project_dirs).each { |id| add(errors, "project-directory-missing", registry_file, id) }
(project_dirs - registry_ids).each { |id| add(errors, "project-unregistered", ROOT.join("projects", id), id) }

lifecycles = %w[active paused finished archived]
registry["projects"].each do |p|
  add(errors, "lifecycle-invalid", registry_file, "#{p["id"]}: #{p["lifecycle"]} (usa #{lifecycles.join(", ")})") unless lifecycles.include?(p["lifecycle"])
end

project_dirs.each do |id|
  dir = ROOT.join("projects", id)
  manifest_file = dir.join("manifest.yaml")
  add(errors, "manifest-missing", manifest_file, id) unless manifest_file.exist?
  add(errors, "project-file-missing", dir.join("project.md"), id) unless dir.join("project.md").exist?
  next unless manifest_file.exist?

  begin
    manifest = load_yaml_file(manifest_file)
    add(errors, "manifest-id-mismatch", manifest_file, "#{manifest["project_id"]} != #{id}") unless manifest["project_id"] == id
    add(errors, "memory-scope-invalid", manifest_file, "Debe ser project:#{id}") unless manifest.dig("memory", "scope") == "project:#{id}"
    add(errors, "cross-project-open", manifest_file, "cross_project debe ser deny") unless manifest.dig("memory", "cross_project") == "deny"
    Array(manifest.dig("tools", "write")).each do |target|
      add(errors, "write-scope-broad", manifest_file, "#{target} (solo projects/#{id})") unless target == "projects/#{id}"
    end
  rescue StandardError
    # El error de YAML ya quedó registrado.
  end
end

# --- Estados consistentes (DEC-002) ---
closed_pattern = /\A\s*(archiv|finaliz|finish|cerrad|closed|termin)/i
state_head = ->(text) { text.to_s.sub(/\A\s*(Estado|Status):\s*/, "").split(/[(;.,]/).first.to_s }
index_file = ROOT.join("projects/index.md")
index_lines = index_file.file? ? index_file.read.lines : []
registry["projects"].each do |p|
  id = p["id"].to_s
  closed = %w[archived finished].include?(p["lifecycle"])
  project_file = ROOT.join("projects", id, "project.md")
  if project_file.file?
    estado = project_file.read.lines.find { |l| l.start_with?("Estado:", "Status:") }
    if estado.nil?
      add(errors, "estado-missing", project_file, "Falta la línea Estado: (o Status:)")
    elsif state_head.(estado).match?(closed_pattern) != closed
      add(errors, "estado-incongruente", project_file, "registro: #{p["lifecycle"]} / #{estado.strip}")
    end
  end
  row = index_lines.find { |l| l.start_with?("|") && l.include?("`projects/#{id}`") }
  if row.nil?
    add(errors, "index-row-missing", index_file, id)
  elsif state_head.(row.split("|")[2]).match?(closed_pattern) != closed
    add(errors, "index-incongruente", index_file, "#{id}: registro #{p["lifecycle"]} / índice: #{row.split("|")[2].strip}")
  end
end

# --- PRs citados en tareas (opcional, requiere gh) ---
if pr_check
  pr_refs = %r{github\.com/([\w.-]+/[\w.-]+)/pull/(\d+)|\b([\w.-]+/[\w.-]+)#(\d+)}
  files_in("projects/*/{tareas,tasks}.md").each do |file|
    file.read.lines.each_with_index do |line, i|
      next unless line.match?(/\A\s*- \[ \]/)
      line.scan(pr_refs).each do |a, b, c, d|
        repo, number = a ? [a, b] : [c, d]
        state = `gh pr view #{number} --repo #{repo} --json state -q .state 2>/dev/null`.strip
        if state.empty?
          add(warnings, "pr-unverified", file, "línea #{i + 1}: no se pudo consultar #{repo}##{number}")
        elsif state == "MERGED"
          add(errors, "tarea-abierta-con-pr-mergeado", file, "línea #{i + 1}: #{repo}##{number} ya está mergeado")
        end
      end
    end
  end
end

# --- Enlaces rotos ---
markdown_files = files_in(["*.md", "{ONBOARDING,knowledge,projects,registry,docs,templates,decisions,adapters,modules,i18n}/**/*.md"])
markdown_files.each do |file|
  file.read.scan(/\[[^\]]+\]\(([^)\s]+)\)/).flatten.each do |target|
    next if target.start_with?("http://", "https://", "mailto:", "#")
    path = target.split("#", 2).first
    next if path.nil? || path.empty? || path.include?("{{") || path.include?("<")
    add(errors, "link-broken", file, target) unless file.dirname.join(path).cleanpath.exist?
  end
end

# --- Secretos ---
secret_patterns = {
  "private-key" => /-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----/,
  "generic-secret" => /(?:api[_-]?key|token|password|secret)\s*[:=]\s*["']?[A-Za-z0-9_\-]{18,}/i,
  "github-token" => /gh[pousr]_[A-Za-z0-9]{20,}/,
  "openai-key" => /sk-[A-Za-z0-9_-]{20,}/,
  "aws-key" => /\bAKIA[0-9A-Z]{16}\b/,
  "slack-token" => /\bxox[abprs]-[A-Za-z0-9-]{10,}/,
  "google-key" => /\bAIza[0-9A-Za-z_-]{35}\b/
}
files_in(["*.{md,yaml,yml}", "{ONBOARDING,knowledge,projects,registry,templates,decisions,docs,adapters,modules,skills}/**/*"]).each do |file|
  text = (file.read rescue next)
  next unless text.valid_encoding?
  secret_patterns.each do |name, pattern|
    add(errors, "possible-secret-#{name}", file, "Patrón sensible detectado") if text.match?(pattern)
  end
end

# --- Módulo finanzas (español) / finance module (inglés) ---
[
  { dir: "projects/finanzas/data", rows: "gastos.csv", cats: "categorias.csv", cols: %w[fecha categoria monto moneda nota] },
  { dir: "projects/finance/data", rows: "expenses.csv", cats: "categories.csv", cols: %w[date category amount currency note] }
].each do |mod|
  gastos = ROOT.join(mod[:dir], mod[:rows])
  categorias = ROOT.join(mod[:dir], mod[:cats])
  next unless gastos.file?
  fecha_col, cat_col, monto_col, moneda_col = mod[:cols]
  begin
    cats = categorias.file? ? CSV.read(categorias.to_s, headers: true, encoding: "bom|utf-8").map { |r| r["id"] } : []
    add(errors, "csv-categorias-missing", categorias, "Falta #{mod[:cats]}") unless categorias.file?
    rows = CSV.read(gastos.to_s, headers: true, encoding: "bom|utf-8")
    add(errors, "csv-header", gastos, "Cabecera esperada: #{mod[:cols].join(",")}") unless rows.headers == mod[:cols]
    previous = ""
    rows.each_with_index do |r, i|
      line = i + 2
      add(errors, "csv-categoria", gastos, "línea #{line}: categoría desconocida (#{r[cat_col]})") unless cats.include?(r[cat_col])
      add(errors, "csv-monto", gastos, "línea #{line}: monto no numérico") unless r[monto_col].to_s.match?(/\A-?\d+(\.\d+)?\z/)
      add(errors, "csv-moneda", gastos, "línea #{line}: moneda de tres letras") unless r[moneda_col].to_s.match?(/\A[A-Z]{3}\z/)
      fecha = r[fecha_col].to_s
      if fecha.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        add(errors, "csv-orden", gastos, "línea #{line}: fecha fuera de orden (#{fecha} después de #{previous})") if fecha < previous
        previous = fecha
      else
        add(errors, "csv-fecha", gastos, "línea #{line}: fecha no ISO (AAAA-MM-DD)")
      end
    end
  rescue StandardError => e
    add(errors, "csv-invalid", gastos, e.message.lines.first.strip)
  end
end

# --- Listas: no se pierden filas respecto de una base (salvo KOS_ALLOW_ROW_DROP=1) ---
# Base: HEAD (cambios sin commitear) o KOS_BASE (en CI, el commit anterior al push).
# Un commit con [permitir-borrar-filas] o [allow-row-drop] en el mensaje autoriza el borrado.
git = ->(*args) { Open3.capture2e("git", "-C", ROOT.to_s, *args) }
row_base = ENV["KOS_BASE"].to_s
row_base = "HEAD" if row_base.empty? || row_base.match?(/\A0+\z/) || !git.("cat-file", "-e", "#{row_base}^{commit}")[1].success?
row_drop_allowed = row_base != "HEAD" && git.("log", "--format=%B", "#{row_base}..HEAD")[0].match?(/\[(permitir-borrar-filas|allow-row-drop)\]/)
if rows_check && ENV["KOS_ALLOW_ROW_DROP"] != "1" && !row_drop_allowed && ROOT.join(".git").exist?
  files_in("knowledge/lists/*.md").each do |file|
    rel = relative(file)
    old, st = git.("show", "#{row_base}:#{rel}")
    next unless st.success?
    old = old.force_encoding(Encoding::UTF_8)
    next if old.empty?
    before = old.lines.count { |l| l.start_with?("|") }
    after = file.read.lines.count { |l| l.start_with?("|") }
    add(errors, "list-rows-dropped", file, "#{before} -> #{after} filas de tabla") if after < before
  end
end

# --- Skills compartidas: formato, casos de prueba y que nada cambie sin pasar por kos_skills.rb aprobar ---
if Pathname.new(__dir__).join("kos_skills.rb").file?
  require_relative "kos_skills"
  skill_errors, skill_warnings = KosSkills.revisar(ROOT)
  skill_errors.each { |code, file, message| add(errors, code, ROOT.join(file), message) }
  skill_warnings.each { |code, file, message| add(warnings, code, ROOT.join(file), message) }
end

# --- Actualización: conflictos pendientes (archivos .kos-new) ---
Dir.glob(ROOT.join("**/*.kos-new").to_s, File::FNM_DOTMATCH).each do |p|
  add(warnings, "update-conflict", Pathname.new(p), "Versión nueva sin revisar: compárala con el archivo original y bórrala")
end

# --- Instalación: no quedan marcadores {{...}} sin completar ---
if installed
  files_in(["AGENTS.md", "CLAUDE.md", "GEMINI.md", "kos.yaml", "{ONBOARDING,knowledge,decisions,projects,.claude,.cursor}/**/*"]).each do |file|
    text = (file.read rescue next)
    next unless text.valid_encoding?
    text.scan(/\{\{[A-Z_]+\}\}/).uniq.each { |m| add(errors, "placeholder-pendiente", file, m) }
  end
else
  add(warnings, "kos-no-instalado", ROOT.join("kos.yaml"), "Corre ruby tools/kos_init.rb (in English: ruby tools/kos_init.rb --lang en)")
end

puts "Validador de KOS"
puts "Raíz: #{ROOT}"
puts "YAML: #{yaml_files.size} | Markdown: #{markdown_files.size} | Proyectos: #{registry["projects"].size}"
puts "Errores: #{errors.size} | Advertencias: #{warnings.size}"
errors.each { |f| puts "ERROR [#{f[:code]}] #{f[:file]} — #{f[:message]}" }
warnings.each { |f| puts "AVISO [#{f[:code]}] #{f[:file]} — #{f[:message]}" }
exit(errors.empty? ? 0 : 1)
