#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8

# kos_doctor.rb — Chequeo de salud de KOS con varios agentes. Sin IA.
#
# Uso: ruby tools/kos_doctor.rb [--arreglar] [--silencioso]
#   --arreglar   corrige lo seguro: permisos de grupo, candado de Git abandonado, temporales viejos, reclamos vencidos
#                (los permisos solo los puede corregir root o el dueño de cada archivo)
#   --silencioso no imprime nada si todo está bien (para chequeos periódicos que solo avisan si hay algo)
# Revisa: permisos, index.lock abandonado, cambios sin commitear hace más de 2 h, sincronización con GitHub,
# índice de decisiones, validador. Sale con 1 si encontró algo.

require "open3"
require "json"
require "time"
require "pathname"
require "fileutils"
require "etc"

ROOT = Pathname.new(ENV["KOS_ROOT"] || File.join(__dir__, "..")).expand_path
arreglar = ARGV.include?("--arreglar")
silencioso = ARGV.include?("--silencioso")
problems = []
fixed = []

def git(*args) = Open3.capture3("git", "-C", ROOT.to_s, *args)[0] # sin avisos de Git (carpetas privadas que el usuario no puede leer)

# 1. Permisos, solo si KOS está compartido entre usuarios (carpeta raíz con setgid): todo editable por su grupo.
#    Ej.: un servidor donde dos agentes corren con usuarios distintos del mismo grupo.
shared = (File.stat(ROOT).mode & 0o2000).positive? rescue false
group = shared ? File.stat(ROOT).gid : nil
bad = []
if shared
  Dir.glob(ROOT.join("**/*").to_s, File::FNM_DOTMATCH).each do |p|
    next if p.end_with?("/.", "/..") || p.include?("/.git/objects/")
    st = File.lstat(p) rescue next
    next if st.symlink?
    bad << p if (st.mode & 0o020).zero? || st.gid != group
  end
end
if bad.any?
  if arreglar
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
    problems << "#{bad.size} archivos sin escritura de grupo (ej.: #{bad.first.delete_prefix("#{ROOT}/")})"
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

# 8. Validador.
vout, = Open3.capture2e("ruby", ROOT.join("tools/kos_validate.rb").to_s, ROOT.to_s)
errores = vout[/Errores: (\d+)/, 1].to_i
problems << "validador: #{errores} errores (#{vout.lines.grep(/\AERROR/).first.to_s.strip[0, 120]})" if errores.positive?

unless silencioso && problems.empty? && fixed.empty?
  puts "KOS: todo bien." if problems.empty? && fixed.empty?
  fixed.each { |f| puts "- KOS arreglado: #{f}" }
  problems.each { |p| puts "- KOS: #{p}" }
end
exit(problems.empty? ? 0 : 1)
