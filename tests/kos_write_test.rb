#!/usr/bin/env ruby
# encoding: utf-8
# Prueba de kos_write.rb con varios agentes a la vez. Trabaja SIEMPRE sobre un clon temporal de KOS.
# Uso: ruby tools/kos_write_test.rb

require "tmpdir"
require "open3"
require "fileutils"
require "yaml"
require "date"

SRC = File.expand_path(ENV["KOS_TEST_SRC"] || File.join(__dir__, ".."))
$failures = []
def check(cond, msg) = ($failures << msg unless cond)

Dir.mktmpdir("kos-write-test-") do |tmp|
  kos = File.join(tmp, "kos")
  # KOS es de otro usuario: Git pide safe.directory. Se usa una config global temporal, sin tocar la real.
  gitconfig = File.join(tmp, "gitconfig")
  File.write(gitconfig, "[safe]\n\tdirectory = *\n")
  _, st = Open3.capture2e({ "GIT_CONFIG_GLOBAL" => gitconfig }, "git", "clone", "-q", SRC, kos)
  abort "No se pudo clonar KOS" unless st.success? && File.directory?(File.join(kos, ".git"))
  abort "El clon apunta al KOS real" if File.realpath(kos) == File.realpath(SRC)
  FileUtils.cp(File.join(SRC, "tools/kos_write.rb"), File.join(kos, "tools/kos_write.rb"))
  FileUtils.mkdir_p(File.join(kos, "tools/lib")) # kos_write.rb carga tools/lib/kos_como_servicio.rb
  FileUtils.cp_r(File.join(SRC, "tools/lib/."), File.join(kos, "tools/lib"))
  g = ->(*a) { Open3.capture2e("git", "-C", kos, "-c", "user.name=t", "-c", "user.email=t@t", *a) }
  g.("add", "tools"); g.("commit", "-qm", "kos_write")
  env = { "KOS_ROOT" => kos, "KOS_AGENTE" => nil } # sin agente heredado de la terminal
  w = ->(agente, *a) { Open3.capture2e(env.merge("KOS_AGENTE" => agente), "ruby", File.join(kos, "tools/kos_write.rb"), *a) }
  # Proyecto de prueba: el primero con archivo de tareas y sección Backlog. Sirve para el KOS propio y la plantilla.
  en = File.read(File.join(kos, "kos.yaml"))[/^lang:\s*(\w+)/, 1] == "en" rescue false
  tfile = en ? "tasks.md" : "tareas.md"
  proj = ENV["KOS_TEST_PROYECTO"] || Dir.children(File.join(kos, "projects")).sort.find do |d|
    File.read(File.join(kos, "projects", d, tfile)).include?("## Backlog") rescue false
  end
  abort "No hay proyecto con #{tfile} y ## Backlog para probar" unless proj
  done = en ? "done" : "hecha"
  trel = "projects/#{proj}/#{tfile}"
  tareas = File.join(kos, trel)
  File.write(tareas, File.read(tareas).sub("## Backlog", "- [ ] AJENO SIN COMMITEAR (creada 2026-01-01)\n\n## Backlog"))

  # 1. Tres agentes agregan tareas a la vez al mismo archivo.
  agents = %w[claude codex/kos cursor/curador]
  threads = agents.map { |a| Thread.new { 5.times.map { |i| w.(a, "tarea", "agregar", "--proyecto", proj, "--texto", "prueba #{a} #{i}")[1].success? } } }
  oks = threads.flat_map(&:value)
  check(oks.all?, "fallaron #{oks.count(false)} escrituras en paralelo")
  head = g.("show", "HEAD:#{trel}")[0]
  check(head.scan(/^- \[ \] prueba /).size == 15, "en HEAD hay #{head.scan(/^- \[ \] prueba /).size}/15 tareas")
  check(File.read(tareas).scan(/^- \[ \] prueba /).size == 15, "en disco no están las 15 tareas")
  check(File.read(tareas).include?("AJENO SIN COMMITEAR"), "se perdió el cambio ajeno sin commitear")
  check(!head.include?("AJENO SIN COMMITEAR"), "el cambio ajeno entró a un commit")
  authors = g.("log", "-15", "--format=%ae")[0].lines.map(&:strip).uniq.sort
  check(authors == %w[claude@kos.local codex-kos@kos.local cursor-curador@kos.local], "autores: #{authors}")

  # 2. Cerrar una tarea la mueve a Hechas.
  _, st = w.("claude", "tarea", "cerrar", "--proyecto", proj, "--buscar", "prueba claude 3")
  check(st.success? && g.("show", "HEAD:#{trel}")[0].include?("- [x] prueba claude 3 (#{done}"), "no cerró la tarea")

  # 2b. Tarea registrada ya hecha, con detalle (lo usa kos_bridge.py log).
  _, st = w.("codex", "tarea", "agregar", "--proyecto", proj, "--seccion", "En curso", "--hecha", "--texto", "avance x", "--detalle", "Registrado por el puente.")
  head2 = g.("show", "HEAD:#{trel}")[0]
  check(st.success? && head2.include?("- [x] avance x (#{done}") && head2.include?("\n      Registrado por el puente."), "--hecha/--detalle no escribió bien")

  # 3. Decisiones en paralelo: números distintos.
  ds = agents.map { |a| Thread.new { w.(a, "decision", "--titulo", "Prueba #{a}", "--proyecto", proj, "--texto", "Texto.")[0] } }.map(&:value)
  ids = ds.map { |o| o[/DEC-\d+/] }
  check(ids.compact.uniq.size == 3, "números de decisión repetidos o ausentes: #{ids}")
  out, = w.("claude", "decision", "--titulo", "Título con: dos puntos", "--proyecto", proj, "--texto", "x")
  fm = File.read(File.join(kos, out[/decisions\S+/].to_s))[/\A---\n(.*?)\n---/m, 1].to_s
  check((YAML.safe_load(fm, permitted_classes: [Date])["title"] rescue nil) == "Título con: dos puntos", "título con ':' rompe el YAML de la decisión")

  # 4. Inbox con el mismo tema el mismo día: dos archivos, no se pisan.
  a = w.("claude", "inbox", "--titulo", "Mismo tema", "--texto", "uno")[0][/knowledge\S+/]
  b = w.("codex", "inbox", "--titulo", "Mismo tema", "--texto", "dos")[0][/knowledge\S+/]
  check(a && b && a != b, "el inbox pisó una captura: #{a} #{b}")

  # 5. Un cambio que rompe la validación no se escribe.
  before = g.("rev-parse", "HEAD")[0]
  _, st = w.("claude", "archivo", "--ruta", "knowledge/inbox/roto.md", "--texto", "[roto](no-existe.md)\n")
  check(!st.success? && g.("rev-parse", "HEAD")[0] == before && !File.exist?(File.join(kos, "knowledge/inbox/roto.md")), "aceptó un enlace roto")

  # 6. Reclamos: otro agente no puede tomar lo tomado.
  w.("codex", "tomar", "--proyecto", proj, "--minutos", "10", "--nota", "prueba")
  _, st = w.("claude", "tomar", "--proyecto", proj)
  check(st.exitstatus == 3, "dejó tomar un proyecto ya tomado")
  check(w.("claude", "reclamos")[0].include?("codex"), "reclamos no lista a codex")

  # 7. Sin agente no escribe.
  _, st = Open3.capture2e(env, "ruby", File.join(kos, "tools/kos_write.rb"), "inbox", "--titulo", "x", "--texto", "y")
  check(st.exitstatus == 2, "escribió sin --agente")
end

if $failures.empty?
  puts "OK — kos_write.rb pasó todas las pruebas."
else
  puts "FALLAS (#{$failures.size}):"
  $failures.each { |f| puts "- #{f}" }
  exit 1
end
