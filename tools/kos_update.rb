#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8
ARGV.map! { |a| a.dup.force_encoding(Encoding::UTF_8) }

# kos_update.rb — Actualiza KOS a una versión nueva sin tocar tus datos.
#
# Uso:  ruby tools/kos_update.rb --desde <carpeta o ZIP de la versión nueva>
#         --simular       muestra qué cambiaría, sin escribir nada
#         --sobrescribir  reemplaza también los archivos de motor que editaste (Git guarda lo anterior)
#         --kos RAIZ      KOS a actualizar (por defecto, el que contiene este archivo)
# In English: --from, --dry-run, --overwrite, --root.
#
# Cómo funciona:
# 1. Instala la versión nueva en una carpeta temporal con tus datos de kos.yaml (nombre, trato, módulos, IAs).
# 2. Copia los archivos de motor (ver tools/kos_motor.rb) que no editaste. Si editaste uno, queda el tuyo
#    y la versión nueva se guarda al lado como <archivo>.kos-new para que elijas.
# 3. Corre las migraciones de datos de la versión nueva (tools/migraciones/) y el validador.
# Nunca toca knowledge/, projects/, decisions/, registry/ ni tus valores de kos.yaml.

require "optparse"
require "pathname"
require "fileutils"
require "tmpdir"
require "open3"
require "yaml"
require_relative "kos_motor"

opts = {}
OptionParser.new do |o|
  o.banner = "Uso: ruby tools/kos_update.rb --desde <carpeta|zip> [opciones]"
  o.on("--desde ORIGEN", "--from SOURCE", "Carpeta o ZIP de la versión nueva") { |v| opts[:desde] = v }
  o.on("--simular", "--dry-run", "Mostrar qué cambiaría, sin escribir") { opts[:simular] = true }
  o.on("--sobrescribir", "--overwrite", "Reemplazar también los archivos de motor editados") { opts[:sobrescribir] = true }
  o.on("--kos RAIZ", "--root ROOT", "KOS a actualizar") { |v| opts[:kos] = v }
  o.on("--sin-delegar", "(interno)") { opts[:sin_delegar] = true }
  o.on("--ayuda", "--help", "Mostrar esta ayuda") { puts o; exit }
end.parse!

ROOT = Pathname.new(opts[:kos] || File.join(__dir__, "..")).expand_path
config_path = ROOT.join("kos.yaml")
abort "No encuentro kos.yaml en #{ROOT} / kos.yaml not found" unless config_path.file?
config = YAML.load_file(config_path.to_s) || {}
EN = config["lang"] == "en"
def t(es, en) = EN ? en : es

abort t("Falta --desde <carpeta o ZIP de la versión nueva>.", "Missing --from <folder or ZIP of the new version>.") unless opts[:desde]
abort t("Este KOS no está instalado: corre ruby tools/kos_init.rb.", "This KOS is not set up: run ruby tools/kos_init.rb --lang en.") unless config["instalado"] == true || config["installed"] == true
abort t("Hace falta Git en la carpeta de KOS para poder deshacer.", "KOS must be a Git repository so the update can be undone.") unless ROOT.join(".git").exist?
dirty, = Open3.capture2("git", "-C", ROOT.to_s, "status", "--porcelain")
unless dirty.strip.empty? || opts[:simular]
  abort t("Tienes cambios sin guardar. Primero: git add -A && git commit -m \"antes de actualizar\"",
          "You have unsaved changes. First: git add -A && git commit -m \"before update\"")
end

# Busca la raíz de KOS dentro de lo extraído (el ZIP trae una carpeta kos/).
def kos_root_in(dir)
  return dir if dir.join("kos.yaml").file?
  kids = dir.children.select(&:directory?)
  kids.size == 1 && kids.first.join("kos.yaml").file? ? kids.first : nil
end

Dir.mktmpdir("kos-update-") do |tmp|
  tmp = Pathname.new(tmp)
  src = Pathname.new(opts[:desde]).expand_path
  if src.file?
    out = tmp.join("zip")
    FileUtils.mkdir_p(out)
    quiet = { out: File::NULL, err: File::NULL }
    ok = system("tar", "-xf", src.to_s, "-C", out.to_s, **quiet) && kos_root_in(out)
    ok ||= system("unzip", "-q", "-o", src.to_s, "-d", out.to_s, **quiet) && kos_root_in(out)
    abort t("No pude abrir #{src}. Descomprímelo y pasa la carpeta.", "Could not open #{src}. Unzip it and pass the folder.") unless ok
    src = kos_root_in(out)
  end
  src = src.directory? ? kos_root_in(src) : nil
  abort t("#{opts[:desde]} no parece una versión de KOS.", "#{opts[:desde]} does not look like a KOS version.") unless src&.join("tools/kos_init.rb")&.file?

  # La versión nueva sabe mejor cómo actualizarse: si trae otro actualizador, se le pasa el trabajo.
  new_updater = src.join("tools/kos_update.rb")
  if !opts[:sin_delegar] && new_updater.file? && KosMotor.sha(new_updater) != KosMotor.sha(__FILE__)
    args = ["--desde", src.to_s, "--kos", ROOT.to_s, "--sin-delegar"]
    args << "--simular" if opts[:simular]
    args << "--sobrescribir" if opts[:sobrescribir]
    exit(system("ruby", new_updater.to_s, *args) ? 0 : 1)
  end

  # 1. Instalación limpia de la versión nueva con tus datos.
  fresh = tmp.join("nueva")
  FileUtils.mkdir_p(fresh)
  src.children.reject { |c| %w[.git backups .kos].include?(c.basename.to_s) }.each { |c| FileUtils.cp_r(c, fresh) }
  dueno = config["dueno"] || config["owner"] || {}
  mods = (config["modulos"] || config["modules"] || {}).select { |_k, on| on == true }.keys
  ias = Array(config["ias"] || config["ais"]).map(&:to_s)
  args = ["--si", "--lang", EN ? "en" : "es", "--areas", "", "--modulos", mods.join(","), "--ias", ias.join(",")]
  { "--nombre" => dueno["nombre"] || dueno["name"], "--idioma" => dueno["idioma"] || dueno["language"],
    "--trato" => dueno["trato"] || dueno["address"], "--estilo" => dueno["estilo"] || dueno["style"] }.each do |flag, v|
    args += [flag, v.to_s] unless v.to_s.empty?
  end
  out, st = Open3.capture2e("ruby", fresh.join("tools/kos_init.rb").to_s, *args, stdin_data: "")
  abort t("La versión nueva no se pudo preparar:\n#{out}", "The new version could not be prepared:\n#{out}") unless st.success?

  # 2. Plan: qué se agrega, actualiza, deja como conflicto o borra.
  # La lista de archivos de motor la dicta la versión nueva: puede sumar carpetas (ej. skills/ en 1.5.0).
  %i[GLOBS LOCK NEW_SUFFIX].each { |c| KosMotor.send(:remove_const, c) if KosMotor.const_defined?(c, false) }
  load fresh.join("tools/kos_motor.rb").to_s
  new_files = KosMotor.current_hashes(fresh)
  lock = KosMotor.read_lock(ROOT)
  if lock.nil? && !opts[:sobrescribir]
    abort t("Este KOS es anterior a 1.3.0 y no sabe qué archivos editaste. Corre de nuevo con --sobrescribir:\n" \
            "reemplaza todo el motor (tus datos no se tocan) y Git guarda lo anterior.",
            "This KOS predates 1.3.0 and can't tell which files you edited. Run again with --overwrite:\n" \
            "it replaces the whole engine (your data is untouched) and Git keeps the previous version.")
  end
  owned = lock ? lock["files"] : {}
  plan = Hash.new { |h, k| h[k] = [] }
  new_files.each do |rel, h|
    cur = ROOT.join(rel)
    next plan[:nuevo] << rel unless cur.file?
    c = KosMotor.sha(cur)
    next if c == h || (!opts[:sobrescribir] && owned[rel] == h) # igual, o la versión nueva no lo cambió
    plan[opts[:sobrescribir] || owned[rel] == c ? :actualizar : :conflicto] << rel
  end
  (owned.keys - new_files.keys).each do |rel|
    cur = ROOT.join(rel)
    next unless cur.file?
    plan[opts[:sobrescribir] || KosMotor.sha(cur) == owned[rel] ? :borrar : :conservar] << rel
  end

  from_v = lock ? lock["version"] : t("anterior a 1.3.0", "before 1.3.0")
  to_v = KosMotor.version(fresh)
  labels = { nuevo: t("nuevos", "new"), actualizar: t("actualizados", "updated"),
             conflicto: t("editados por ti (la versión nueva queda en .kos-new)", "edited by you (new version saved as .kos-new)"),
             borrar: t("eliminados (ya no existen)", "removed (no longer shipped)"),
             conservar: t("ya no son del motor; quedan como tuyos", "no longer part of the engine; kept as yours") }
  puts t("KOS #{from_v} → #{to_v}#{opts[:simular] ? " (simulación)" : ""}", "KOS #{from_v} → #{to_v}#{opts[:simular] ? " (dry run)" : ""}")
  labels.each do |key, label|
    next if plan[key].empty?
    puts "#{label}: #{plan[key].size}"
    plan[key].each { |rel| puts "  #{rel}" }
  end
  puts t("Nada que cambiar.", "Nothing to change.") if plan.values.all?(&:empty?)
  exit 0 if opts[:simular]

  # 3. Aplicar.
  (plan[:nuevo] + plan[:actualizar]).each do |rel|
    FileUtils.mkdir_p(ROOT.join(rel).dirname)
    FileUtils.cp(fresh.join(rel), ROOT.join(rel), preserve: true)
  end
  plan[:conflicto].each { |rel| FileUtils.cp(fresh.join(rel), ROOT.join(rel + KosMotor::NEW_SUFFIX), preserve: true) }
  plan[:borrar].each { |rel| FileUtils.rm_f(ROOT.join(rel)) }
  hook = ROOT.join(".git/hooks/pre-commit")
  if !hook.exist? && fresh.join(".git/hooks/pre-commit").file?
    FileUtils.mkdir_p(hook.dirname)
    FileUtils.cp(fresh.join(".git/hooks/pre-commit"), hook, preserve: true)
  end

  # 4. Migraciones de datos: tools/migraciones/NNN-nombre.rb, en orden, de tu schema_version a la nueva.
  have = config["schema_version"].to_i
  want = (YAML.load_file(fresh.join("kos.yaml").to_s) || {})["schema_version"].to_i
  Dir[fresh.join("tools/migraciones/*.rb").to_s].sort.each do |mig|
    n = File.basename(mig)[/\A\d+/].to_i
    next unless n > have && n <= want
    mout, mst = Open3.capture2e("ruby", mig, ROOT.to_s)
    puts mout unless mout.strip.empty?
    abort t("Falló la migración #{File.basename(mig)}. Para deshacer todo: git reset --hard && git clean -fd",
            "Migration #{File.basename(mig)} failed. To undo everything: git reset --hard && git clean -fd") unless mst.success?
    puts t("  migración #{File.basename(mig)} ✓", "  migration #{File.basename(mig)} ✓")
  end
  if want > have
    config_path.write(config_path.read.sub(/^schema_version:\s*\d+/, "schema_version: #{want}"))
  end

  # El lock guarda la versión nueva tal como vino: lo que dejaste como tuyo seguirá marcado como editado.
  KosMotor.write_lock(ROOT, new_files, to_v)
  ok = system("ruby", ROOT.join("tools/kos_validate.rb").to_s, ROOT.to_s)
  puts
  unless plan[:conflicto].empty?
    puts t("Compara cada archivo editado con su .kos-new, quédate con lo que quieras y borra el .kos-new.",
           "Compare each edited file with its .kos-new, keep what you want and delete the .kos-new.")
  end
  puts t("Revisa con git diff y guarda: git add -A && git commit -m \"KOS #{to_v}\"\nPara deshacer: git reset --hard && git clean -fd",
         "Review with git diff and save: git add -A && git commit -m \"KOS #{to_v}\"\nTo undo: git reset --hard && git clean -fd")
  exit(ok ? 0 : 1)
end
