# encoding: utf-8
# kos_motor.rb — Qué archivos son "motor" (los trae cada versión de KOS) y cuáles son tus datos.
#
# Motor: reglas, herramientas, manual, moldes, módulos y adaptadores. El actualizador los reemplaza.
# Datos: todo lo demás (knowledge/, projects/, decisions/, registry/, kos.yaml). Nunca se tocan.
# .kos/lock.yaml guarda la versión instalada y el SHA256 de cada archivo de motor tal como quedó
# al instalar o actualizar. Si hoy el archivo es distinto, lo editaste tú y el actualizador no lo pisa.

require "digest"
require "yaml"
require "fileutils"
require "pathname"

module KosMotor
  GLOBS = %w[
    VERSION AGENTS.md README.md LICENSE.md CHANGELOG.md CLAUDE.md GEMINI.md
    ONBOARDING/**/* tools/**/* tests/**/* docs/**/* adapters/**/* templates/**/* modules/**/*
    .claude/skills/kos/**/* .cursor/rules/kos.mdc .github/workflows/**/*
    skills/README.md skills/skills-kos/SKILL.md skills/skills-kos/CAMBIOS.md skills/skills-kos/evals/casos.md
  ].freeze
  LOCK = ".kos/lock.yaml"
  NEW_SUFFIX = ".kos-new"

  module_function

  def files(root)
    root = Pathname.new(root)
    GLOBS.flat_map { |g| Dir.glob(root.join(g).to_s, File::FNM_DOTMATCH) }
         .select { |p| File.file?(p) && !p.end_with?(NEW_SUFFIX) }
         .map { |p| Pathname.new(p).relative_path_from(root).to_s }.uniq.sort
  end

  def sha(path) = Digest::SHA256.file(path.to_s).hexdigest

  def read_lock(root)
    path = Pathname.new(root).join(LOCK)
    return nil unless path.file?
    data = YAML.safe_load(path.read) || {}
    { "version" => data["version"].to_s, "files" => data["files"] || {} }
  end

  def version(root)
    file = Pathname.new(root).join("VERSION")
    file.file? ? file.read.strip : "0"
  end

  def write_lock(root, hashes, version)
    path = Pathname.new(root).join(LOCK)
    FileUtils.mkdir_p(path.dirname)
    path.write("# Generado por KOS: versión instalada y huella de cada archivo de motor. No lo edites.\n" +
               YAML.dump({ "version" => version, "files" => hashes.sort.to_h }))
  end

  def current_hashes(root) = files(root).to_h { |rel| [rel, sha(Pathname.new(root).join(rel))] }

  # Archivos de motor que hoy coinciden con el lock (no los editaste).
  def untouched(root)
    lock = read_lock(root) or return []
    lock["files"].select { |rel, h| (f = Pathname.new(root).join(rel)).file? && sha(f) == h }.keys
  end

  # Corre el bloque y actualiza el lock de los archivos que el propio KOS cambió (módulos, rellenar).
  # Los que ya habías editado a mano siguen marcados como tuyos.
  def preserving_lock(root)
    lock = read_lock(root)
    return yield unless lock
    before = untouched(root)
    known = lock["files"].keys
    result = yield
    hashes = lock["files"].dup
    current_hashes(root).each { |rel, h| hashes[rel] = h if before.include?(rel) || !known.include?(rel) }
    write_lock(root, hashes, lock["version"])
    result
  end
end
