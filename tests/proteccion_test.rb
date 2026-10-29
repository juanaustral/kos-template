#!/usr/bin/env ruby
# encoding: utf-8
# Prueba de kos_proteccion.rb y del modo de prueba de kos_proteger.rb, siempre sobre una copia temporal de KOS.
# (El cierre real, con usuarios de verdad, se prueba aparte en un contenedor: no se puede hacer sin root.)
require "tmpdir"
require "open3"
require "fileutils"

SRC = File.expand_path(ENV["KOS_TEST_SRC"] || File.join(__dir__, ".."))
fallas = []
Dir.mktmpdir("kos-proteccion-test-") do |tmp|
  kos = File.join(tmp, "kos")
  FileUtils.mkdir_p(kos)
  Dir.children(SRC).reject { |c| %w[.git backups].include?(c) }.each { |c| FileUtils.cp_r(File.join(SRC, c), kos) }
  Open3.capture2e("git", "init", "-q", "-b", "main", kos)
  env = { "KOS_ROOT" => kos, "KOS_ESTADO" => File.join(tmp, "estado"), "KOS_CONFIG" => File.join(tmp, "cfg.json") }
  run = ->(*a) { Open3.capture2e(env, "ruby", File.join(kos, "tools", a.shift), *a) }

  out, st = run.call("kos_proteccion.rb", "nivel")
  fallas << "nivel no informa: #{out}" unless st.success? && out =~ /nivel [01] de 3/ && out.include?("Zonas definidas")
  fallas << "dice que hay aprobación activa sin PIN" if out =~ /Aprobación por email activa.*sí/
  _, st = run.call("kos_proteccion.rb", "nivel", "--exigir", "3")
  fallas << "--exigir 3 no falló en un KOS sin proteger" if st.success?
  out, st = run.call("kos_proteccion.rb", "ataque")
  fallas << "ataque no corre: #{out}" unless st.success? && out.include?("Prueba de ataque")
  fallas << "ataque no probó kos_write sobre la zona crítica" unless out.include?("escribir AGENTS.md por kos_write")
  fallas << "ataque dejó archivos de prueba en KOS" if Dir.glob(File.join(kos, ".kos-prueba-*")).any? || Dir.glob(File.join(kos, "tools", ".kos-prueba-*")).any?
  # Con PIN y correo el nivel sube a 2 (en una copia suelta, sin hook activo todavía)
  File.write(env["KOS_CONFIG"], '{"destinatario":"t@t","correo_env":"/dev/null"}')
  Open3.capture2e(env.merge("KOS_TEST_ENTRADA" => "482913\n482913"), "ruby", File.join(kos, "tools/kos_pin.rb"))
  Open3.capture2e("git", "-C", kos, "config", "core.hooksPath", "tools/hooks")
  out, = run.call("kos_proteccion.rb", "nivel")
  fallas << "con PIN, correo y hook el nivel no llegó a 2: #{out.lines.first}" unless out.include?("nivel 2 de 3") || out.include?("nivel 3 de 3")
  # El modo de prueba de kos_proteger no cambia nada
  antes = Dir.glob(File.join(kos, "**/*"), File::FNM_DOTMATCH).size
  out, st = run.call("kos_proteger.rb", "--agentes", "ana")
  fallas << "kos_proteger sin --cerrar no explicó qué haría: #{out}" unless st.success? && out.include?("agregá --cerrar")
  fallas << "kos_proteger sin --cerrar cambió archivos" unless Dir.glob(File.join(kos, "**/*"), File::FNM_DOTMATCH).size == antes
  _, st = run.call("kos_proteger.rb", "--cerrar")
  fallas << "kos_proteger --cerrar sin --agentes no abortó" if st.success?
end
if fallas.empty? then puts "proteccion_test: OK"; exit 0
else puts "proteccion_test FALLÓ:\n- #{fallas.join("\n- ")}"; exit 1 end
