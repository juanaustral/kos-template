#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8
ARGV.map! { |a| a.dup.force_encoding(Encoding::UTF_8) }

# kos_write.rb — Puerta única de escritura en KOS para varios agentes de IA a la vez.
#
# Uso: ruby tools/kos_write.rb --agente <nombre> <operación> [opciones]   (o KOS_AGENTE=<nombre>)
#   tarea agregar --proyecto ID --texto "Título — contexto" [--seccion "Por hacer"] [--hecha] [--detalle "segunda línea"]
#   tarea cerrar  --proyecto ID --buscar "parte del título"
#   inbox         --titulo "Tema" (--texto "..." | --archivo F | --archivo -)
#   decision      --titulo "..." --proyecto ID (--texto | --archivo)     # número asignado sin choques, estado: propuesta
#   lista         --lista movies.md --fila "| a | b |"
#   archivo       --ruta R --archivo F        # crea o reemplaza un archivo entero (para lo que no tiene operación)
#   tomar         --proyecto ID [--minutos 30] [--nota "..."]   # reclamo: "estoy trabajando en esto"
#   soltar        --proyecto ID
#   reclamos                                  # quién está trabajando en qué
#   cierre        [--desde "3 hours ago"]     # arma el Cierre con los commits de este agente
#
# Garantías:
# - Un candado (.git/kos-write.lock) hace que las escrituras pasen de a una: nadie pisa a nadie.
# - El commit contiene solo este cambio, aplicado sobre HEAD, con el agente como autor. Los cambios
#   sin commitear de otros agentes en el mismo archivo se conservan en disco y no entran al commit.
# - Antes de commitear valida el árbol resultante; si aparece un error nuevo, no escribe nada.
# - No usa el índice compartido de Git para commitear: no choca con index.lock.
# Sale con 0 si escribió, 1 si falló la validación o la operación, 2 si el uso es incorrecto, 3 si hay un reclamo ajeno.

require "optparse"
require "pathname"
require "fileutils"
require "open3"
require "json"
require "date"
require "time"
require "tmpdir"
require "rubygems/package"
require "stringio"
require "yaml"

ROOT = Pathname.new(ENV["KOS_ROOT"] || File.join(__dir__, "..")).expand_path
require_relative "lib/kos_como_servicio"
KosComoServicio.relanzar(File.realpath(__FILE__), ROOT)
MODO_ARCHIVO = KosComoServicio.modo_archivo(ROOT)
LOCK_FILE = ROOT.join(".git/kos-write.lock")
CLAIMS_FILE = ROOT.join(".git/kos-claims.json")
TODAY = Date.today.iso8601
# Formatos según el idioma del KOS (kos.yaml → lang: en); sin kos.yaml o sin lang, español.
EN = (File.read(ROOT.join("kos.yaml"))[/^lang:\s*(\w+)/, 1] == "en" rescue false)
L = if EN
      { tasks: "tasks.md", created: "created", done: "done", proposed: "proposed",
        sections: { "Por hacer" => "To do", "En curso" => "In progress", "Hechas" => "Done", "Bloqueadas" => "Blocked", "Backlog" => "Backlog" },
        inbox: %w[Source Date Status Sensitivity], sensitivity: "internal",
        msg_task: "new task", msg_done: "task done", msg_row: "new row in" }
    else
      { tasks: "tareas.md", created: "creada", done: "hecha", proposed: "propuesta", sections: {},
        inbox: %w[Origen Fecha Estado Sensibilidad], sensitivity: "interna",
        msg_task: "tarea nueva", msg_done: "tarea hecha", msg_row: "fila nueva en" }
    end
def section(name) = L[:sections].fetch(name, name)
def tasks_rel(proyecto) = "projects/#{proyecto}/#{L[:tasks]}"

class KosError < StandardError
  attr_reader :code
  def initialize(msg, code = 1)
    super(msg)
    @code = code
  end
end

opts = { seccion: "Por hacer", minutos: 30, desde: "12 hours ago" }
parser = OptionParser.new do |o|
  o.banner = "Uso: ruby tools/kos_write.rb --agente NOMBRE <operación> [opciones]"
  o.on("--agente NOMBRE") { |v| opts[:agente] = v }
  %i[proyecto texto seccion buscar titulo archivo lista fila ruta nota desde mensaje].each do |k|
    o.on("--#{k} VALOR") { |v| opts[k] = v }
  end
  o.on("--minutos N", Integer) { |v| opts[:minutos] = v }
  o.on("--hecha", "La tarea se registra ya hecha") { opts[:hecha] = true }
  o.on("--detalle TEXTO", "Segunda línea, sangrada") { |v| opts[:detalle] = v }
  o.on("--ayuda") { puts File.read(__FILE__)[/^# kos_write.*?^# Sale con[^\n]*/m].gsub(/^# ?/, ""); exit }
end
parser.parse!
op = ARGV.shift
sub = ARGV.shift if op == "tarea"
agente = (opts[:agente] || ENV["KOS_AGENTE"]).to_s.strip.downcase

def git(*args, env: {}, stdin: nil, ok: true)
  out, err, st = Open3.capture3(env, "git", "-C", ROOT.to_s, *args, stdin_data: stdin.to_s, binmode: true)
  raise KosError, "git #{args.first} falló: #{err.strip[0, 300]}" if ok && !st.success?
  [out.force_encoding(Encoding::UTF_8), st.success?]
end

def head_text(rel)
  out, ok = git("show", "HEAD:#{rel}", ok: false)
  ok ? out : nil
end

def slug(text)
  text.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")[0, 60]
end

def with_lock(timeout = 120)
  File.open(LOCK_FILE, File::RDWR | File::CREAT, MODO_ARCHIVO) do |f|
    File.chmod(MODO_ARCHIVO, LOCK_FILE) rescue nil # con umask 022 quedaría cerrado para los otros usuarios del grupo
    deadline = Time.now + timeout
    until f.flock(File::LOCK_EX | File::LOCK_NB)
      raise KosError, "KOS ocupado más de #{timeout}s (candado #{LOCK_FILE})" if Time.now > deadline
      sleep 0.2
    end
    yield
  end
end

def read_body(opts)
  return opts[:texto] if opts[:texto]
  return $stdin.read if opts[:archivo] == "-"
  return File.read(opts[:archivo], encoding: "utf-8") if opts[:archivo]
  raise KosError.new("Falta --texto o --archivo", 2)
end

def need(opts, *keys)
  keys.each { |k| raise KosError.new("Falta --#{k}", 2) if opts[k].to_s.strip.empty? }
end

def free_path(rel)
  base = rel.sub(/\.md\z/, "")
  candidate = rel
  n = 1
  while ROOT.join(candidate).exist? || head_text(candidate)
    n += 1
    candidate = "#{base}-#{n}.md"
  end
  candidate
end

# --- Validación: errores nuevos del árbol resultante respecto de HEAD ---
def validation_errors(tree)
  Dir.mktmpdir("kos-write-") do |tmp|
    archive, = Open3.capture2("git", "-C", ROOT.to_s, "archive", "--format=tar", tree, binmode: true)
    Gem::Package::TarReader.new(StringIO.new(archive)).each do |entry| # sin tar externo: anda igual en Windows
      dest = File.join(tmp, entry.full_name)
      if entry.directory?
        FileUtils.mkdir_p(dest)
      elsif entry.file?
        FileUtils.mkdir_p(File.dirname(dest))
        File.binwrite(dest, entry.read.to_s)
      end
    end
    out, = Open3.capture2e("ruby", ROOT.join("tools/kos_validate.rb").to_s, tmp)
    out.force_encoding(Encoding::UTF_8).lines.grep(/\AERROR /).map { |l| l.gsub(tmp, "").strip }
  end
end

# --- Zona crítica: estas rutas no se escriben por acá; se piden con tools/kos_aprobar.rb ---
# La lista sale de registry/zonas.yaml tal como está en HEAD (editar el archivo en disco no la cambia).
ZONA_CRITICA_RESPALDO = %w[AGENTS.md ONBOARDING/ tools/ registry/zonas.yaml .claude/ .github/ .gitignore].freeze
def zona_critica?(rel)
  zonas = YAML.safe_load(head_text("registry/zonas.yaml").to_s) rescue nil
  rutas = Array(zonas.is_a?(Hash) ? zonas.dig("critica", "rutas") : nil)
  rutas = ZONA_CRITICA_RESPALDO if rutas.empty?
  rutas.any? { |z| rel == z || rel.start_with?(z.end_with?("/") ? z : "#{z}/") }
end

# --- Transacción: aplica cambios sobre HEAD (para el commit) y sobre el disco (para conservar lo ajeno) ---
# changes: { "ruta" => ->(texto_o_nil) { nuevo_texto } }
def transact(changes, agente, message)
  changes.each_key do |rel|
    raise KosError.new("#{rel} es zona crítica: no se escribe con kos_write. Requiere la aprobación del titular: tools/kos_aprobar.rb solicitar.", 4) if zona_critica?(rel)
  end
  3.times do
    head, = git("rev-parse", "HEAD")
    head.strip!
    plan = changes.map do |rel, fn|
      in_head = head_text(rel)
      disk = ROOT.join(rel).file? ? File.read(ROOT.join(rel), encoding: "utf-8") : nil
      new_head = fn.call(in_head)
      new_disk = disk == in_head ? new_head : fn.call(disk)
      [rel, new_head, new_disk]
    end

    Dir.mktmpdir("kos-index-") do |tmp|
      env = { "GIT_INDEX_FILE" => File.join(tmp, "index") }
      git("read-tree", head, env: env)
      plan.each do |rel, new_head, _|
        blob, = git("hash-object", "-w", "--stdin", stdin: new_head)
        git("update-index", "--add", "--cacheinfo", "100644,#{blob.strip},#{rel}", env: env)
      end
      tree, = git("write-tree", env: env)
      tree.strip!
      head_tree, = git("rev-parse", "#{head}^{tree}")
      fresh = validation_errors(tree) - validation_errors(head_tree.strip)
      raise KosError, "La validación falló; no se escribió nada:\n#{fresh.join("\n")}" unless fresh.empty?

      author = { "GIT_AUTHOR_NAME" => agente.split(/[\/_-]/).map(&:capitalize).join("/"),
                 "GIT_AUTHOR_EMAIL" => "#{agente.tr("/", "-")}@kos.local" }
      commit, = git("commit-tree", tree, "-p", head, "-m", message, env: author)
      commit.strip!
      _, moved = git("update-ref", "-m", "kos_write: #{message[0, 60]}", "HEAD", commit, head, ok: false)
      next unless moved # alguien commiteó por fuera entre medio: se reintenta sobre el HEAD nuevo

      plan.each do |rel, new_head, new_disk|
        path = ROOT.join(rel)
        FileUtils.mkdir_p(path.dirname)
        tmpfile = path.dirname.join(".#{path.basename}.kos-tmp-#{$$}")
        File.write(tmpfile, new_disk)
        File.chmod(MODO_ARCHIVO, tmpfile)
        File.rename(tmpfile, path)
        sync_index(rel, head, new_head)
      end
      return commit
    end
  end
  raise KosError, "HEAD cambió tres veces seguidas; probá de nuevo"
end

# Deja el índice compartido igual a HEAD para ese archivo, salvo que otro agente tenga algo preparado ahí.
def sync_index(rel, old_head, new_text)
  staged, = git("ls-files", "-s", "--", rel, ok: false)
  old_blob, had = git("rev-parse", "#{old_head}:#{rel}", ok: false)
  return unless staged.strip.empty? ? !had : staged.split[1] == old_blob.strip
  blob, = git("hash-object", "-w", "--stdin", stdin: new_text)
  20.times do
    _, ok = git("update-index", "--add", "--cacheinfo", "100644,#{blob.strip},#{rel}", ok: false)
    return if ok
    sleep 0.5
  end
  warn "Aviso: no pude actualizar el índice para #{rel} (index.lock ocupado); git status puede mostrarlo raro."
end

# --- Reclamos ---
def claims
  data = CLAIMS_FILE.file? ? JSON.parse(CLAIMS_FILE.read) : {}
  data.select { |_k, c| Time.parse(c["hasta"]) > Time.now }
rescue JSON::ParserError
  {}
end

def save_claims(data)
  File.write(CLAIMS_FILE, JSON.pretty_generate(data))
  File.chmod(MODO_ARCHIVO, CLAIMS_FILE)
end

def warn_claim(proyecto, agente)
  c = claims[proyecto]
  warn "Aviso: #{c["agente"]} está trabajando en #{proyecto} hasta #{c["hasta"][11, 5]} (#{c["nota"]})" if c && c["agente"] != agente
end

# --- Operaciones sobre texto ---
def insert_in_section(text, section, line)
  raise KosError, "El archivo no existe en HEAD" if text.nil?
  lines = text.lines
  i = lines.index { |l| l.strip == "## #{section}" } or raise KosError, "No hay sección '## #{section}'"
  j = i + 1
  j += 1 while lines[j]&.strip&.empty?
  lines.insert(j, "#{line}\n")
  lines.insert(j + 1, "\n") unless lines[j + 1].nil? || lines[j + 1].start_with?("- ", "  ")
  lines.join
end

def close_task(text, needle)
  raise KosError, "El archivo no existe en HEAD" if text.nil?
  lines = text.lines
  hits = lines.each_index.select { |k| lines[k].start_with?("- [ ]") && lines[k].downcase.include?(needle.downcase) }
  raise KosError, "Ninguna tarea abierta contiene '#{needle}'" if hits.empty?
  raise KosError, "Hay #{hits.size} tareas abiertas con '#{needle}'; sé más preciso" if hits.size > 1
  k = hits.first
  block = [lines[k]]
  block << lines[k + block.size] while lines[k + block.size]&.match?(/\A {2,}\S/)
  lines.slice!(k, block.size)
  block[0] = block[0].sub("- [ ]", "- [x]").sub(/\s*\((creada|created) [^)]*\)\s*$/, "").rstrip + " (#{L[:done]} #{TODAY})\n"
  insert_in_section(lines.join, section("Hechas"), block.join.chomp)
end

def append_table_row(text, row)
  raise KosError, "La lista no existe en HEAD" if text.nil?
  lines = text.lines
  last = lines.rindex { |l| l.start_with?("|") } or raise KosError, "La lista no tiene tabla"
  lines.insert(last + 1, "#{row.strip}\n")
  lines.join
end

begin
  if %w[tarea inbox decision lista archivo tomar soltar].include?(op) && !agente.match?(%r{\A[a-z0-9][a-z0-9/_-]{0,30}\z})
    raise KosError.new("Falta --agente (ej.: claude, codex, cursor/agente) o KOS_AGENTE", 2)
  end

  case [op, sub]
  in ["tarea", "agregar"]
    need(opts, :proyecto, :texto)
    rel = tasks_rel(opts[:proyecto])
    warn_claim(opts[:proyecto], agente)
    line = opts[:hecha] ? "- [x] #{opts[:texto].strip} (#{L[:done]} #{TODAY})" : "- [ ] #{opts[:texto].strip} (#{L[:created]} #{TODAY})"
    line += "\n      #{opts[:detalle].strip}" if opts[:detalle]
    with_lock { puts transact({ rel => ->(t) { insert_in_section(t, section(opts[:seccion]), line) } }, agente, opts[:mensaje] || "#{opts[:proyecto]}: #{L[:msg_task]}") }
  in ["tarea", "cerrar"]
    need(opts, :proyecto, :buscar)
    rel = tasks_rel(opts[:proyecto])
    with_lock { puts transact({ rel => ->(t) { close_task(t, opts[:buscar]) } }, agente, opts[:mensaje] || "#{opts[:proyecto]}: #{L[:msg_done]}") }
  in ["inbox", nil]
    need(opts, :titulo)
    body = read_body(opts)
    with_lock do
      rel = free_path("knowledge/inbox/#{TODAY}-#{slug(opts[:titulo])}.md")
      o, f, e, se = L[:inbox]
      text = "# #{opts[:titulo].strip}\n\n#{o}: #{agente}\n#{f}: #{TODAY}\n#{e}: proposed\n#{se}: #{L[:sensitivity]}\n\n#{body.strip}\n"
      puts transact({ rel => ->(_) { text } }, agente, opts[:mensaje] || "inbox: #{opts[:titulo].strip}")
      puts rel
    end
  in ["decision", nil]
    need(opts, :titulo, :proyecto)
    body = read_body(opts)
    with_lock do
      used = (Dir[ROOT.join("decisions/DEC-*.md").to_s].map { |p| File.basename(p) } +
              git("ls-tree", "--name-only", "HEAD", "decisions/")[0].lines.map { |l| File.basename(l.strip) })
             .filter_map { |n| n[/\ADEC-(\d+)/, 1]&.to_i }
      id = format("DEC-%03d", (used.max || 0) + 1)
      rel = "decisions/#{id}-#{slug(opts[:titulo])}.md"
      text = "---\nid: #{id}\ntitle: #{opts[:titulo].strip.to_json}\nstatus: #{L[:proposed]}\ndate: #{TODAY}\nproject_id: #{opts[:proyecto]}\n" \
             "source: #{agente} vía kos_write.rb\ntype: decision\nsensitivity: interna\n---\n# #{id} — #{opts[:titulo].strip}\n\n#{body.strip}\n"
      row = "| #{id} | #{TODAY} | #{opts[:titulo].strip.tr("|", "/")} | #{L[:proposed]} | #{opts[:proyecto]} |"
      puts transact({ rel => ->(_) { text }, "decisions/index.md" => ->(t) { append_table_row(t, row) } },
                    agente, opts[:mensaje] || "decisions: #{id} #{opts[:titulo].strip} (#{L[:proposed]})")
      puts rel
    end
  in ["lista", nil]
    need(opts, :lista, :fila)
    rel = "knowledge/lists/#{File.basename(opts[:lista])}"
    with_lock { puts transact({ rel => ->(t) { append_table_row(t, opts[:fila]) } }, agente, opts[:mensaje] || "lists: #{L[:msg_row]} #{File.basename(rel)}") }
  in ["archivo", nil]
    need(opts, :ruta)
    rel = Pathname.new(opts[:ruta]).cleanpath.to_s
    raise KosError.new("Ruta fuera de KOS o interna: #{rel}", 2) if rel.start_with?("/", "..", ".git/") || rel == ".git"
    body = read_body(opts)
    with_lock do
      disk = ROOT.join(rel).file? ? File.read(ROOT.join(rel), encoding: "utf-8") : nil
      raise KosError, "#{rel} tiene cambios sin commitear de otro agente; no lo piso" if disk && disk != head_text(rel)
      puts transact({ rel => ->(_) { body } }, agente, opts[:mensaje] || "#{rel.split("/")[0, 2].join("/")}: actualizado")
    end
  in ["tomar", nil]
    need(opts, :proyecto)
    with_lock do
      data = claims
      c = data[opts[:proyecto]]
      raise KosError.new("#{c["agente"]} ya está en #{opts[:proyecto]} hasta #{c["hasta"][11, 5]} (#{c["nota"]})", 3) if c && c["agente"] != agente
      data[opts[:proyecto]] = { "agente" => agente, "hasta" => (Time.now + opts[:minutos] * 60).iso8601, "nota" => opts[:nota].to_s }
      save_claims(data)
      puts "#{agente} tomó #{opts[:proyecto]} por #{opts[:minutos]} min"
    end
  in ["soltar", nil]
    need(opts, :proyecto)
    with_lock do
      data = claims
      data.delete(opts[:proyecto]) if data.dig(opts[:proyecto], "agente") == agente
      save_claims(data)
      puts "#{agente} soltó #{opts[:proyecto]}"
    end
  in ["reclamos", nil]
    list = claims
    puts list.empty? ? "Nadie tiene proyectos tomados." : list.map { |p, c| "#{p}: #{c["agente"]} hasta #{c["hasta"][11, 5]} #{c["nota"]}" }
  in ["cierre", nil]
    raise KosError.new("Falta --agente", 2) if agente.empty?
    out, = git("log", "--author=#{agente.tr("/", "-")}@kos.local", "--since=#{opts[:desde]}", "--name-only", "--format=")
    files = out.lines.map(&:strip).reject(&:empty?).uniq
    vout, = Open3.capture2e("ruby", ROOT.join("tools/kos_validate.rb").to_s, ROOT.to_s)
    puts "Registrado en KOS: #{files.empty? ? "nada para registrar" : files.join(", ")}"
    puts "Comprobado con: validador — #{vout[/Errores: \d+/] || "sin resultado"}"
    puts "Falta: (completar)"
  else
    raise KosError.new(parser.banner + "\nOperaciones: tarea agregar|cerrar, inbox, decision, lista, archivo, tomar, soltar, reclamos, cierre. Ayuda: --ayuda", 2)
  end
rescue KosError => e
  warn e.message
  exit e.code
end
