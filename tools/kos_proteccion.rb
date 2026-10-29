#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8
ARGV.map! { |a| a.dup.force_encoding(Encoding::UTF_8) }
# kos_proteccion.rb — Dice qué nivel de protección tiene tu KOS *para quien corre esto* y lo comprueba con pruebas reales.
#
#   ruby tools/kos_proteccion.rb nivel              diagnóstico, sin tocar nada
#   ruby tools/kos_proteccion.rb ataque             intenta saltear las barreras como el usuario actual (reversible) e informa qué pasó
#   ruby tools/kos_proteccion.rb nivel --exigir 2   sale con error si el nivel es menor (para scripts)
#
# Corré esto con el mismo usuario con el que trabaja tu IA: el nivel depende de quién eres tú en el sistema, no del KOS.
#   0  Sin protección: no hay zonas ni vigilancia.
#   1  Guía y detección: zonas definidas, hook de push y doctor. Avisan y rechazan por la puerta de escritura, pero una IA que
#      edite archivos directo con tu mismo usuario puede saltearlos.
#   2  Guía + aprobación del titular por email (código y PIN): los cambios críticos pasan por kos_aprobar.rb.
#   3  Cerrado: KOS es de otro usuario y quien corre esto no puede escribir directo, ni usar sudo, ni leer el secreto de aprobaciones.
require "etc"
require "open3"
require "yaml"
require "pathname"
require_relative "lib/kos_aprobacion"
require_relative "lib/kos_como_servicio"

ROOT = Pathname.new(ENV["KOS_ROOT"] || File.join(__dir__, "..")).expand_path
K = KosAprobacion
def git(*a) = Open3.capture3("git", "-C", ROOT.to_s, *a)
def ok?(c) = c ? "sí" : "NO"

def puede_escribir_en(dir)
  nombre = File.join(dir, ".kos-prueba-#{Process.pid}")
  File.open(nombre, "w") { |f| f.write("x") }
  true
rescue SystemCallError
  false
ensure
  File.delete(nombre) if nombre && File.exist?(nombre)
end

def evaluar
  yo = Etc.getpwuid(Process.uid).name
  es_root = Process.uid.zero?
  sudo_libre = !es_root && Open3.capture2e("sudo", "-n", "true")[1].success? rescue false
  zonas = (YAML.safe_load(File.read(ROOT.join("registry/zonas.yaml"))) rescue nil)
  hooks = git("config", "core.hooksPath")[0].strip == "tools/hooks" && ROOT.join("tools/hooks/pre-push").executable?
  cerrado = KosComoServicio.cerrado?(ROOT)
  directo = puede_escribir_en(ROOT.to_s) || puede_escribir_en(ROOT.join("tools").to_s)
  git_escribe = File.writable?(ROOT.join(".git").to_s)
  secreto_legible = File.readable?(K.secreto_path.to_s)
  activa = K.secreto_path.exist? || (File.directory?(K::ESTADO.to_s) && !File.readable?(K::ESTADO.to_s))
  config = K::CONFIG.exist? || (File.directory?(K::CONFIG.dirname.to_s) && !File.readable?(K::CONFIG.dirname.to_s))
  c = { usuario: yo, root: es_root, sudo_libre: sudo_libre, zonas: !zonas.nil?, hooks: hooks, aprobacion: activa && config,
        cerrado: cerrado, escribe_directo: directo || git_escribe, lee_secreto: secreto_legible }
  nivel = 0
  nivel = 1 if c[:zonas] && c[:hooks]
  nivel = 2 if nivel >= 1 && c[:aprobacion]
  nivel = 3 if nivel >= 2 && c[:cerrado] && !c[:escribe_directo] && !c[:root] && !c[:sudo_libre] && !c[:lee_secreto]
  c.merge(nivel: nivel)
end

def informe(c)
  puts "Protección de este KOS para el usuario «#{c[:usuario]}»: nivel #{c[:nivel]} de 3"
  puts "  Zonas definidas (registry/zonas.yaml):          #{ok?(c[:zonas])}"
  puts "  Hook que frena force push y borrar ramas:       #{ok?(c[:hooks])}"
  puts "  Aprobación por email activa (PIN y correo):     #{ok?(c[:aprobacion])}"
  puts "  KOS pertenece a un usuario de servicio (`kos`): #{ok?(c[:cerrado])}"
  puts "  Este usuario puede escribir directo en KOS:     #{c[:escribe_directo] ? "SÍ (puede saltearse las reglas)" : "no"}"
  puts "  Este usuario es root o tiene sudo sin clave:    #{c[:root] || c[:sudo_libre] ? "SÍ (puede saltearse todo)" : "no"}"
  puts "  Este usuario puede leer el secreto de aprobaciones: #{c[:lee_secreto] ? "SÍ" : "no"}"
  puts
  puts({ 0 => "Sin protección. Define zonas y activa el hook: ruby tools/kos_doctor.rb --arreglar.",
         1 => "Guía y detección: avisa y rechaza lo crítico por la puerta de escritura, pero este usuario puede saltearlo. Para subir: configurar el email y crear el PIN (docs/manual/13-proteccion.md).",
         2 => "Con aprobación por email. Falta cerrar el servidor (usuario `kos`, sin escritura directa): ruby tools/kos_proteger.rb --ayuda. En un equipo de un solo usuario este es el techo.",
         3 => "Cerrado: para este usuario, los cambios críticos solo pasan con el código y el PIN del titular." }[c[:nivel]])
end

def ataque(c)
  puts "Prueba de ataque como «#{c[:usuario]}» (todo reversible):"
  pruebas = [
    ["escribir un archivo en la raíz de KOS", puede_escribir_en(ROOT.to_s)],
    ["escribir un archivo en tools/ (donde viven las barreras)", puede_escribir_en(ROOT.join("tools").to_s)],
    ["crear archivos dentro de .git (commitear directo)", File.writable?(ROOT.join(".git").to_s)],
    ["leer el secreto de aprobaciones (PIN y clave del código)", File.readable?(K.secreto_path.to_s)],
    ["ser root o usar sudo sin clave", c[:root] || c[:sudo_libre]]
  ]
  pruebas.each { |nombre, logro| puts "  #{logro ? "PASÓ (mal)" : "bloqueado  "}  #{nombre}" }
  # La puerta de escritura rechaza la zona crítica: se prueba sobre un clon descartable, nunca sobre tu KOS.
  require "tmpdir"
  Dir.mktmpdir("kos-ataque-") do |tmp|
    clon = File.join(tmp, "kos")
    _, st = Open3.capture2e({ "GIT_CONFIG_GLOBAL" => File.join(tmp, "g") }, "git", "clone", "-q", ROOT.to_s, clon)
    File.write(File.join(tmp, "g"), "[safe]\n\tdirectory = *\n")
    _, st = Open3.capture2e({ "GIT_CONFIG_GLOBAL" => File.join(tmp, "g") }, "git", "clone", "-q", ROOT.to_s, clon) unless st.success?
    if st.success?
      FileUtils.cp_r(ROOT.join("tools").to_s + "/.", File.join(clon, "tools")) rescue nil
      FileUtils.cp(ROOT.join("registry/zonas.yaml").to_s, File.join(clon, "registry/zonas.yaml")) rescue nil
      File.write(File.join(tmp, "x"), "x")
      out, = Open3.capture2e({ "KOS_ROOT" => clon, "KOS_AGENTE" => "prueba" }, "ruby", File.join(clon, "tools/kos_write.rb"), "--agente", "prueba",
                             "archivo", "--ruta", "AGENTS.md", "--archivo", File.join(tmp, "x"))
      puts "  #{out.include?("zona crítica") ? "bloqueado  " : "PASÓ (mal)"}  escribir AGENTS.md por kos_write (clon descartable)"
    else
      puts "  (no se pudo armar el clon de prueba para kos_write)"
    end
  end
  puts
  puts "Esto confirma el nivel #{c[:nivel]}. Un «PASÓ» en las primeras filas significa que quien corre esto puede saltearse las reglas con herramientas directas."
end

require "fileutils"
c = evaluar
if ARGV.first == "ataque"
  ataque(c)
else
  informe(c)
  if (i = ARGV.index("--exigir")) && c[:nivel] < ARGV[i + 1].to_i
    warn "Nivel #{c[:nivel]} < #{ARGV[i + 1]} exigido."
    exit 1
  end
end
