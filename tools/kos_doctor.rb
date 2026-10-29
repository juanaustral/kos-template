#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8

# kos_doctor.rb — Chequeo de salud de KOS con varios agentes. Sin IA.
#
# Uso: ruby tools/kos_doctor.rb [--arreglar] [--silencioso]
#   --arreglar   corrige lo seguro: permisos de grupo, candado de Git abandonado, temporales viejos, reclamos vencidos
#                (los permisos solo los puede corregir root o el dueño de cada archivo)
#   --visto      da por leídas las alertas de vigilancia pendientes (historia reescrita, borrados masivos)
#   --silencioso no imprime nada si todo está bien (para chequeos periódicos que solo avisan si hay algo)
# Revisa: permisos, index.lock abandonado, cambios sin commitear hace más de 2 h, sincronización con GitHub,
# índice de decisiones, validador. Sale con 1 si encontró algo.

require "open3"
require "json"
require "yaml"
require "time"
require "pathname"
require "fileutils"
require "etc"
require_relative "lib/kos_aprobacion"

ROOT = Pathname.new(ENV["KOS_ROOT"] || File.join(__dir__, "..")).expand_path
require_relative "lib/kos_como_servicio"
KosComoServicio.relanzar(File.realpath(__FILE__), ROOT) unless Process.uid.zero?
CERRADO = KosComoServicio.cerrado?(ROOT)
File.umask(0o022) if CERRADO
arreglar = ARGV.include?("--arreglar")
silencioso = ARGV.include?("--silencioso")
problems = []
fixed = []

def git(*args) = Open3.capture3("git", "-C", ROOT.to_s, *args)[0] # sin avisos de Git (carpetas privadas que el usuario no puede leer)

# 1. Permisos. Modo cerrado: la carpeta de KOS es del usuario `kos`, nadie más escribe; solo `kos` y root (cron) lo mantienen.
#    Modo compartido (instalaciones sin usuario `kos`): todo editable por el grupo de la carpeta raíz.
shared = !CERRADO && (File.stat(ROOT).mode & 0o2000).positive? rescue false
group = shared ? File.stat(ROOT).gid : nil
kos_uid = KosComoServicio.kos&.uid
bad = []
if CERRADO || shared
  Dir.glob(ROOT.join("**/*").to_s, File::FNM_DOTMATCH).each do |p|
    next if p.end_with?("/.", "/..") || p.include?("/.git/objects/")
    next if CERRADO && (p.start_with?(ROOT.join("backups").to_s) || p.start_with?(ROOT.join("exports").to_s))
    st = File.lstat(p) rescue next
    next if st.symlink?
    if CERRADO
      bad << p if st.uid != kos_uid || (st.mode & 0o022).positive?
    else
      bad << p if (st.mode & 0o020).zero? || st.gid != group
    end
  end
end
if bad.any?
  if arreglar && CERRADO
    if Process.uid.zero?
      KosComoServicio.normalizar_dueno(ROOT)
      bad.each { |p| File.chmod(File.lstat(p).mode & ~0o022, p) if (File.lstat(p).mode & 0o022).positive? rescue nil }
    end
    left = bad.count { |p| (st = File.lstat(p) rescue nil) && (st.uid != kos_uid || (st.mode & 0o022).positive?) }
    fixed << "dueño y permisos de #{bad.size - left} archivos (modo cerrado)" if bad.size > left
    problems << "#{left} archivos fuera del modo cerrado (correr como root)" if left.positive?
  elsif arreglar
    bad.each do |p|
      File.chmod(File.lstat(p).mode | 0o020 | (File.directory?(p) ? 0o2000 : 0), p)
      File.chown(nil, group, p) if group
    rescue SystemCallError
      next
    end
    left = bad.count { |p| File.exist?(p) && ((File.lstat(p).mode & 0o020).zero? || (group && File.lstat(p).gid != group)) }
    fixed << "permisos de grupo en #{bad.size - left} archivos"
    problems << "#{left} archivos sin escritura de grupo (correr como root)" if left.positive?
  else
    problems << (CERRADO ? "#{bad.size} archivos que no son de `kos` o admiten escritura ajena (ej.: #{bad.first.delete_prefix("#{ROOT}/")})" : "#{bad.size} archivos sin escritura de grupo (ej.: #{bad.first.delete_prefix("#{ROOT}/")})")
  end
end

# 2. index.lock abandonado (más de 10 min y ningún git corriendo).
lock = ROOT.join(".git/index.lock")
if lock.exist? && Time.now - lock.mtime > 600
  running = (Open3.capture2("pgrep", "-x", "git")[0].strip rescue "") # sin pgrep (Windows): se asume que no corre
  if running.empty? && arreglar
    lock.delete
    fixed << "borrado un .git/index.lock abandonado"
  else
    problems << ".git/index.lock tiene #{((Time.now - lock.mtime) / 60).round} min#{running.empty? ? " (abandonado)" : ""}"
  end
end

# 3. Temporales de escrituras interrumpidas.
Dir.glob(ROOT.join("**/.*.kos-tmp-*").to_s, File::FNM_DOTMATCH).each do |p|
  next unless Time.now - File.mtime(p) > 600
  arreglar ? (File.delete(p) && fixed << "temporal borrado: #{p.delete_prefix("#{ROOT}/")}") : problems << "temporal abandonado: #{p.delete_prefix("#{ROOT}/")}"
end

# 4. Reclamos vencidos.
claims_file = ROOT.join(".git/kos-claims.json")
if claims_file.file?
  data = JSON.parse(claims_file.read) rescue {}
  vivos = data.select { |_k, c| (Time.parse(c["hasta"]) rescue Time.at(0)) > Time.now }
  if vivos.size != data.size && arreglar
    File.write(claims_file, JSON.pretty_generate(vivos))
    fixed << "#{data.size - vivos.size} reclamos vencidos limpiados"
  end
end

# 5. Cambios sin commitear hace más de 2 horas (un agente que se colgó o se olvidó).
viejos = git("status", "--porcelain").lines.map { |l| l[3..].strip.delete('"') }.select do |rel|
  path = ROOT.join(rel)
  path.exist? && Time.now - path.mtime > 7200
end
problems << "#{viejos.size} cambios sin commitear hace más de 2 h: #{viejos.first(3).join(", ")}" if viejos.any?

# 6. Sincronización con GitHub (la hace kos_sync.rb; solo se revisa si alguna vez corrió).
sync_file = ROOT.join(".git/kos-sync.json")
if sync_file.file?
  s = JSON.parse(sync_file.read) rescue {}
  edad = Time.now - (Time.parse(s["fecha"]) rescue Time.at(0))
  problems << "kos_sync: #{s["mensaje"]}" if s["ok"] == false
  problems << "kos_sync no corre hace #{(edad / 60).round} min" if edad > 1800
end

# 7. Índice de decisiones: cada DEC con su fila, y el estado de la fila empieza igual que el del archivo.
idx_file = ROOT.join("decisions/index.md")
if idx_file.file?
  rows = idx_file.read.lines.grep(/\A\| DEC-\d+ \|/).to_h { |l| c = l.strip.delete_suffix("|").split("|").map(&:strip); [c[1], c[-2].to_s] }
  Dir[ROOT.join("decisions/DEC-*.md").to_s].sort.each do |f|
    id = File.basename(f)[/\ADEC-\d+/]
    status = File.read(f)[/^status:\s*(.+)$/, 1].to_s.strip.delete('"')
    if !rows.key?(id)
      problems << "decisions/index.md no tiene fila para #{id}"
    elsif !status.empty? && rows[id].split.first.to_s.downcase != status.split.first.to_s.downcase
      problems << "#{id}: estado en el índice «#{rows[id]}» y en el archivo «#{status}»"
    end
  end
end

# 8b. Vigilancia de estructura. Mira los commits nuevos desde la última pasada.
#     - historia reescrita (el último HEAD vigilado ya no es ancestro del actual)
#     - borrados masivos, o una carpeta de proyecto borrada entera
#     - toques a la zona crítica (registry/zonas.yaml); se anotan en .git/kos-vigia.log para medir cuántos son
vigia = []
zonas = (YAML.load_file(ROOT.join("registry/zonas.yaml").to_s) rescue nil)
if zonas
  marca = ROOT.join(".git/kos-vigia.json")
  head = git("rev-parse", "HEAD").strip
  previo = (JSON.parse(marca.read)["head"] rescue nil)
  rango = nil
  if previo && previo != head
    if !Open3.capture2e("git", "-C", ROOT.to_s, "merge-base", "--is-ancestor", previo, head)[1].success?
      vigia << "historia de KOS reescrita: #{previo[0, 7]} ya no está en #{head[0, 7]} (cambio crítico)"
    else
      rango = "#{previo}..#{head}"
    end
  end
  if rango
    crit = Array(zonas.dig("critica", "rutas"))
    maxb = zonas.dig("critica", "borrados", "max_archivos_por_commit").to_i
    git("log", "--format=%H", rango).split.each do |c|
      cambios = git("diff-tree", "--no-commit-id", "--name-status", "-r", "--root", c).lines.map { |l| l.strip.split("\t", 2) }
      borrados = cambios.select { |st, _| st == "D" }.map(&:last)
      asunto = git("log", "-1", "--format=%an: %s", c).strip[0, 90]
      vigia << "borrado masivo en #{c[0, 7]} (#{borrados.size} archivos): #{asunto}" if maxb.positive? && borrados.size > maxb
      carpetas = borrados.map { |r| r[%r{\Aprojects/[^/]+/}] }.compact.uniq
      carpetas.each do |dir|
        quedan = git("ls-tree", "-r", "--name-only", c, dir).strip
        vigia << "carpeta de proyecto borrada entera en #{c[0, 7]}: #{dir}" if quedan.empty?
      end
      tocadas = cambios.map(&:last).select { |r| crit.any? { |z| r == z || r.start_with?(z) } }
      next if tocadas.empty?
      # Con el PIN creado (zona crítica activa), un cambio crítico posterior a la activación necesita su aprobación registrada.
      sec = KosAprobacion.leer_json(KosAprobacion.secreto_path, nil)
      base = sec && sec["activado_en_head"]
      if base && c != base && Open3.capture2e("git", "-C", ROOT.to_s, "merge-base", "--is-ancestor", base, c)[1].success? && !KosAprobacion.aprobados.include?(c)
        vigia << "cambio crítico sin aprobación en #{c[0, 7]} (#{tocadas.first(3).join(", ")}): #{asunto}"
      end
      File.open(ROOT.join(".git/kos-vigia.log"), "a") { |f| f.puts "#{Time.now.utc.iso8601} #{c[0, 7]} critica: #{tocadas.first(5).join(", ")} | #{asunto}" }
    end
  end
  marca.write(JSON.generate("head" => head, "fecha" => Time.now.utc.iso8601))
end
# Las alertas quedan pendientes hasta que el titular (o una IA, avisándole) las marque con `--visto`: la pasada de cron no las consume.
pend = ROOT.join(".git/kos-alertas.txt")
visto = ARGV.include?("--visto")
nuevas = (pend.file? ? pend.read.lines.map(&:chomp) : []) | vigia
pend.write(visto ? "" : nuevas.map { |l| l + "\n" }.join)
problems.concat(nuevas) unless visto

# 8b2. Modo cerrado: git no debe crear archivos con escritura de grupo (core.sharedRepository los dejaría en 664).
if CERRADO && !git("config", "core.sharedRepository").strip.empty?
  if arreglar
    git("config", "--unset", "core.sharedRepository")
    fixed << "core.sharedRepository quitado (modo cerrado)"
  else
    problems << "core.sharedRepository está activo en modo cerrado (correr con --arreglar)"
  end
end

# 8c. Hooks de Git activos (pre-push frena force y borrado de ramas).
hp = git("config", "core.hooksPath").strip
if hp != "tools/hooks" || !ROOT.join("tools/hooks/pre-push").executable?
  if arreglar && ROOT.join("tools/hooks/pre-push").file?
    File.chmod(0o755, ROOT.join("tools/hooks/pre-push").to_s)
    git("config", "core.hooksPath", "tools/hooks")
    fixed << "hooks de Git activados (core.hooksPath = tools/hooks)"
  else
    problems << "hooks de Git sin activar (core.hooksPath != tools/hooks)"
  end
end

# 8d. Latido: sello de que el doctor corrió (lo mira la prueba semanal, fase 5).
ROOT.join(".git/kos-doctor.json").write(JSON.generate("fecha" => Time.now.utc.iso8601, "problemas" => problems.size)) rescue nil

# 8. Validador.
vout, = Open3.capture2e("ruby", ROOT.join("tools/kos_validate.rb").to_s, ROOT.to_s)
errores = vout[/Errores: (\d+)/, 1].to_i
problems << "validador: #{errores} errores (#{vout.lines.grep(/\AERROR/).first.to_s.strip[0, 120]})" if errores.positive?

KosComoServicio.normalizar_dueno(ROOT)

unless silencioso && problems.empty? && fixed.empty?
  puts "KOS: todo bien." if problems.empty? && fixed.empty?
  fixed.each { |f| puts "- KOS arreglado: #{f}" }
  problems.each { |p| puts "- KOS: #{p}" }
end
exit(problems.empty? ? 0 : 1)
