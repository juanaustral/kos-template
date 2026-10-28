#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8

# Pruebas de las herramientas de KOS. Trabajan sobre copias temporales; no tocan tu KOS.
# Uso: ruby tests/validator_test.rb [RAIZ]

require "tmpdir"
require "fileutils"
require "open3"
require "pathname"

ROOT = Pathname.new(ARGV[0] || File.join(__dir__, "..")).expand_path
$failures = []

def run(*cmd, **kw) = Open3.capture2e(*cmd, **kw)
def check(cond, message) = ($failures << message unless cond)

def with_copy(name)
  Dir.mktmpdir("kos-test-#{name}-") do |tmp|
    copy = Pathname.new(tmp).join("kos")
    FileUtils.mkdir_p(copy)
    Dir.children(ROOT).reject { |c| %w[.git backups].include?(c) }.each { |c| FileUtils.cp_r(ROOT.join(c), copy) }
    yield copy
  end
end

def validate(copy) = run("ruby", copy.join("tools/kos_validate.rb").to_s, copy.to_s)

def init(copy, *args)
  run("ruby", copy.join("tools/kos_init.rb").to_s, "--si", "--nombre", "Persona Prueba", *args, stdin_data: "")
end

# 1. La plantilla vacía valida.
with_copy("vacia") do |copy|
  out, st = validate(copy)
  check(st.success?, "la plantilla vacía no valida:\n#{out}")
end

# 2. Errores clásicos detectados.
with_copy("mutada") do |copy|
  copy.join("projects/mi-primer-proyecto/fuga.md").write("api_key: abcdefghijklmnopqrstuvwxyz123456\n[roto](no-existe.md)\n")
  manifest = copy.join("projects/mi-primer-proyecto/manifest.yaml")
  manifest.write(manifest.read.sub("write: [projects/mi-primer-proyecto]", "write: [knowledge]"))
  out, st = validate(copy)
  check(!st.success?, "no falló con datos inválidos")
  %w[possible-secret-generic-secret link-broken write-scope-broad].each { |c| check(out.include?(c), "no detectó #{c}") }
end

# 3. YAML roto, archivo crítico vacío, estado incongruente.
with_copy("yaml") do |copy|
  copy.join("registry/projects.yaml").write("projects: [sin cerrar\n")
  out, _ = validate(copy)
  check(out.include?("yaml-invalid") || out.include?("registry-missing"), "YAML roto aceptado")
end
with_copy("vacio") do |copy|
  copy.join("AGENTS.md").write("")
  out, _ = validate(copy)
  check(out.include?("required-file-empty"), "AGENTS.md vacío aceptado")
end
with_copy("estado") do |copy|
  index = copy.join("projects/index.md")
  index.write(index.read.sub("| Mi primer proyecto | activo |", "| Mi primer proyecto | archivado |"))
  out, _ = validate(copy)
  check(out.include?("index-incongruente"), "estado incongruente aceptado")
end

# 4. Instalación completa sin preguntas.
with_copy("init") do |copy|
  out, st = init(copy, "--areas", "Trabajo,Salud y bienestar", "--modulos", "listas,finanzas", "--ias", "claude-code,cursor,gemini,codex")
  check(st.success?, "kos_init falló:\n#{out}")
  vout, vst = validate(copy)
  check(vst.success?, "KOS instalado no valida:\n#{vout}")
  %w[CLAUDE.md GEMINI.md .claude/skills/kos/SKILL.md .cursor/rules/kos.mdc knowledge/lists/movies.md
     projects/finanzas/data/gastos.csv knowledge/areas/salud-y-bienestar.md].each do |f|
    check(copy.join(f).exist?, "falta #{f} después de instalar")
  end
  check(copy.join("AGENTS.md").read.include?("Persona Prueba"), "AGENTS.md sin el nombre")
  check(copy.join("kos.yaml").read.include?("instalado: true"), "kos.yaml no quedó instalado")
  check(copy.join("ONBOARDING/RECETAS.md").read.include?("(módulo finanzas)"), "faltan recetas de finanzas")
  check(!copy.join("i18n").exist?, "quedó i18n/ en la instalación en español")

  _, again = init(copy)
  check(!again.success?, "permitió reinstalar sin --forzar")

  gastos = copy.join("projects/finanzas/data/gastos.csv")
  gastos.write(gastos.read + "2026-02-01,comida,100.50,ARS,ok\n2026-01-01,inventada,diez,pesos,mal\n")
  gout, _ = validate(copy)
  %w[csv-categoria csv-monto csv-moneda csv-orden].each { |c| check(gout.include?(c), "no detectó #{c}") }

  # 5. Chequeo de privacidad.
  deny = Pathname.new(Dir.tmpdir).join("kos-test-deny-#{$$}.txt")
  deny.write("# prueba\nPersona Prueba\n")
  pout, pst = run("ruby", copy.join("tools/kos_privacy_check.rb").to_s, "--denylist", deny.to_s, copy.to_s)
  check(!pst.success? && pout.include?("Persona Prueba"), "privacidad no encontró el nombre")
  deny.write(["termino", "inexistente", $$.to_s].join("-") + "\n")
  _, pst2 = run("ruby", copy.join("tools/kos_privacy_check.rb").to_s, "--denylist", deny.to_s, copy.to_s)
  check(pst2.success?, "privacidad dio falso positivo")
  deny.delete
end

# 6. Módulo agregado después, y placeholders pendientes.
with_copy("modulo") do |copy|
  init(copy)
  out, st = run("ruby", copy.join("tools/kos_init.rb").to_s, "--solo-modulo", "listas")
  check(st.success? && copy.join("knowledge/lists/books.md").exist?, "--solo-modulo falló:\n#{out}")
  check(copy.join("kos.yaml").read.match?(/listas:\s*true/), "kos.yaml no marcó el módulo")
  lout, _ = run("ruby", "-I", copy.join("tools").to_s, "-r", "kos_motor", "-e", "puts KosMotor.untouched(ARGV[0])", copy.to_s)
  check(lout.include?("ONBOARDING/RECETAS.md"), "--solo-modulo dejó RECETAS.md como editado a mano en el lock")
  copy.join("knowledge/profile.md").write("# {{OWNER_NAME}}\n")
  vout, _ = validate(copy)
  check(vout.include?("placeholder-pendiente"), "no detectó marcadores sin completar")
end

# 7. Instalación en inglés.
with_copy("en") do |copy|
  out, st = init(copy, "--lang", "en", "--areas", "Work,Health", "--modulos", "lists,finance", "--ias", "claude-code")
  check(st.success?, "kos_init --lang en falló:\n#{out}")
  vout, vst = validate(copy)
  check(vst.success?, "KOS en inglés no valida:\n#{vout}")
  %w[ONBOARDING/RECIPES.md projects/my-first-project/tasks.md projects/finance/data/expenses.csv
     knowledge/lists/movies.md knowledge/areas/health.md docs/manual/00-what-is-kos.md CLAUDE.md].each do |f|
    check(copy.join(f).exist?, "falta #{f} en la instalación en inglés")
  end
  %w[ONBOARDING/RECETAS.md projects/mi-primer-proyecto docs/manual/00-que-es-kos.md i18n README.en.md].each do |f|
    check(!copy.join(f).exist?, "quedó #{f} en la instalación en inglés")
  end
  check(copy.join("ONBOARDING/RECIPES.md").read.include?("(module finance)"), "faltan recetas de finance")
  check(copy.join("kos.yaml").read.include?("installed: true"), "kos.yaml en inglés no quedó instalado")
  check(copy.join("AGENTS.md").read.include?("Form of address: informal"), "AGENTS.md en inglés sin trato")
  ex = copy.join("projects/finance/data/expenses.csv")
  ex.write(ex.read + "2026-01-05,groceries,12.5,USD,ok\n2026-01-01,nope,x,usd,bad\n")
  eout, _ = validate(copy)
  %w[csv-categoria csv-monto csv-moneda csv-orden].each { |c| check(eout.include?(c), "en: no detectó #{c}") }
end
with_copy("en-modulo") do |copy|
  init(copy, "--lang", "en")
  out, st = run("ruby", copy.join("tools/kos_init.rb").to_s, "--only-module", "lists")
  check(st.success? && copy.join("knowledge/lists/books.md").read.include?("Author"), "--only-module en falló:\n#{out}")
  check(copy.join("kos.yaml").read.match?(/lists:\s*true/), "kos.yaml en inglés no marcó el módulo")
end

# 8. Nombres con comillas y barras no rompen el YAML.
with_copy("comillas") do |copy|
  out, st = run("ruby", copy.join("tools/kos_init.rb").to_s, "--si", "--nombre", 'Ana "La Jefa" \\ X', "--ias", "cursor", "--modulos", "finanzas")
  check(st.success?, "nombre con comillas rompió la instalación:\n#{out}")
  check(copy.join("kos.yaml").read.include?('nombre: "Ana \\"La Jefa\\" \\\\ X"'), "kos.yaml no escapó el nombre")
  _, st2 = run("ruby", copy.join("tools/kos_init.rb").to_s, "--solo-modulo", "listas")
  check(st2.success?, "--solo-modulo falló con nombre con comillas")
end

# 9. Filas borradas y ya commiteadas: las detecta comparando contra KOS_BASE (como en CI).
with_copy("filas") do |copy|
  init(copy, "--modulos", "listas")
  check(copy.join(".git/hooks/pre-commit").executable?, "no se instaló el hook pre-commit")
  g = ->(*a) { run("git", "-C", copy.to_s, "-c", "user.name=t", "-c", "user.email=t@t", *a) }
  movies = copy.join("knowledge/lists/movies.md")
  movies.write(movies.read + "| Película de prueba | 2010 |\n")
  g.("add", "-A"); g.("commit", "-qm", "base")
  base = g.("rev-parse", "HEAD")[0].strip
  movies.write(movies.read.lines[0..-2].join)
  _, hook = g.("commit", "-qam", "borra")
  check(!hook.success?, "el hook pre-commit dejó commitear un borrado de filas")
  g.("commit", "-qam", "borra", "--no-verify")
  out, st = run({ "KOS_BASE" => base }, "ruby", copy.join("tools/kos_validate.rb").to_s, copy.to_s)
  check(!st.success? && out.include?("list-rows-dropped"), "no detectó filas borradas ya commiteadas")
  g.("commit", "-q", "--allow-empty", "--no-verify", "-m", "a propósito [permitir-borrar-filas]")
  _, st2 = run({ "KOS_BASE" => base }, "ruby", copy.join("tools/kos_validate.rb").to_s, copy.to_s)
  check(st2.success?, "[permitir-borrar-filas] no autorizó el borrado")
end

# 10. Un error en las preguntas no deja nada a medias.
with_copy("atomica") do |copy|
  _, st = init(copy, "--modulos", "inexistente")
  check(!st.success?, "aceptó un módulo inexistente")
  check(copy.join("i18n/en").directory? && copy.join("README.en.md").exist?, "la instalación fallida borró archivos")
  out, st2 = init(copy, "--lang", "en")
  check(st2.success? && copy.join("ONBOARDING/RECIPES.md").exist?, "después de un error no instaló en inglés:\n#{out}")
end

# 11. Tras actualizar (copiar ONBOARDING/ nuevo), --rellenar completa los marcadores y repone las recetas.
with_copy("rellenar") do |copy|
  pristine = Dir.mktmpdir("kos-onb-")
  FileUtils.cp_r(copy.join("ONBOARDING"), pristine)
  init(copy, "--modulos", "finanzas")
  FileUtils.cp_r(Dir[File.join(pristine, "ONBOARDING", "*")], copy.join("ONBOARDING"))
  vout, _ = validate(copy)
  check(vout.include?("placeholder-pendiente"), "la copia de ONBOARDING no dejó marcadores (prueba mal armada)")
  out, st = run("ruby", copy.join("tools/kos_init.rb").to_s, "--rellenar")
  check(st.success?, "--rellenar falló:\n#{out}")
  check(copy.join("ONBOARDING/RECETAS.md").read.include?("(módulo finanzas)"), "--rellenar no repuso recetas de finanzas")
  FileUtils.rm_rf(pristine)
end

# 12. Actualizar a una versión nueva: motor reemplazado, datos intactos, ediciones respetadas, migraciones.
with_copy("actualizar") do |kos|
  with_copy("version-nueva") do |nueva|
    init(kos, "--modulos", "listas", "--ias", "claude-code")
    g = ->(*a) { run("git", "-C", kos.to_s, "-c", "user.name=t", "-c", "user.email=t@t", *a) }
    kos.join("AGENTS.md").write(kos.join("AGENTS.md").read + "\nMi regla propia.\n")
    movies = kos.join("knowledge/lists/movies.md")
    movies.write(movies.read + "| Película mía | 1999 |\n")
    g.("add", "-A"); g.("commit", "-qm", "instalado")

    onb = nueva.join("ONBOARDING/README.md")
    onb.write(onb.read + "\nLínea nueva de la versión 9.9.9 para {{OWNER_NAME}}.\n")
    nueva.join("AGENTS.md").write(nueva.join("AGENTS.md").read + "\nRegla nueva.\n")
    nueva.join("docs/manual/extra.md").write("# Extra\n")
    nueva.join("tools/migraciones/README.md").delete
    nueva.join("tools/migraciones/002-prueba.rb").write("File.write(File.join(ARGV[0], \"knowledge/migrado.txt\"), \"ok\\n\")\n")
    nueva.join("VERSION").write("9.9.9\n")
    nueva.join("kos.yaml").write(nueva.join("kos.yaml").read.sub("schema_version: 1", "schema_version: 2"))
    upd = nueva.join("tools/kos_update.rb")
    upd.write(upd.read.sub("require_relative \"kos_motor\"\n", "require_relative \"kos_motor\"\nputs \"actualizador nuevo\"\n"))
    updater = kos.join("tools/kos_update.rb").to_s

    sout, sst = run("ruby", updater, "--desde", nueva.to_s, "--simular")
    check(sst.success? && sout.include?("9.9.9"), "--simular falló:\n#{sout}")
    check(g.("status", "--porcelain")[0].strip.empty?, "--simular cambió archivos")

    kos.join("suelto.md").write("x\n")
    _, dst = run("ruby", updater, "--desde", nueva.to_s)
    check(!dst.success?, "actualizó con cambios sin guardar")
    kos.join("suelto.md").delete

    out, st = run("ruby", updater, "--desde", nueva.to_s)
    check(st.success?, "la actualización falló:\n#{out}")
    check(out.include?("actualizador nuevo"), "no delegó en el actualizador de la versión nueva")
    check(kos.join("ONBOARDING/README.md").read.include?("versión 9.9.9 para Persona Prueba"), "no actualizó ni completó ONBOARDING")
    check(kos.join("AGENTS.md").read.include?("Mi regla propia."), "pisó un archivo editado por el dueño")
    check(kos.join("AGENTS.md.kos-new").read.include?("Regla nueva."), "no dejó la versión nueva en .kos-new")
    check(kos.join("docs/manual/extra.md").exist?, "no agregó un archivo de motor nuevo")
    check(!kos.join("tools/migraciones/README.md").exist?, "no quitó un archivo de motor viejo:\n#{out}")
    check(kos.join("knowledge/migrado.txt").exist?, "no corrió la migración")
    check(kos.join("kos.yaml").read.include?("schema_version: 2"), "no subió schema_version")
    check(movies.read.include?("Película mía"), "tocó los datos del dueño")
    check(kos.join(".kos/lock.yaml").read.include?("9.9.9"), "el lock no registró la versión nueva")
    vout, _ = validate(kos)
    check(vout.include?("update-conflict"), "el validador no avisó del .kos-new")

    kos.join("AGENTS.md.kos-new").delete
    g.("add", "-A"); g.("commit", "-qm", "actualizado")
    out2, st2 = run("ruby", updater, "--desde", nueva.to_s)
    check(st2.success? && !kos.join("AGENTS.md.kos-new").exist?, "repitió el conflicto de un archivo que no cambió:\n#{out2}")
  end
end

# 13. Varios agentes a la vez (kos_write.rb), instalado en español y en inglés.
[[], ["--lang", "en"]].each do |extra|
  with_copy("multiagente#{extra.last}") do |copy|
    init(copy, *extra)
    run("git", "-C", copy.to_s, "-c", "user.name=t", "-c", "user.email=t@t", "add", "-A")
    run("git", "-C", copy.to_s, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "instalado")
    out, st = run({ "KOS_TEST_SRC" => copy.to_s }, "ruby", copy.join("tests/kos_write_test.rb").to_s)
    check(st.success?, "kos_write_test (#{extra.last || "es"}) falló:\n#{out}")
    dout, = run("ruby", copy.join("tools/kos_doctor.rb").to_s)
    check(!dout.include?("decisions/index.md no tiene fila"), "kos_doctor (#{extra.last || "es"}) ve el índice de decisiones mal:\n#{dout}")
  end
end

# 14. Respaldo y restauración.
with_copy("backup") do |copy|
  run("git", "-C", copy.to_s, "init", "-q")
  run("git", "-C", copy.to_s, "-c", "user.name=t", "-c", "user.email=t@t", "add", "-A")
  run("git", "-C", copy.to_s, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "base")
  out, st = run("ruby", copy.join("tools/kos_backup.rb").to_s, copy.to_s)
  bundle = out[/Respaldo: (\S+)/, 1]
  check(st.success? && bundle, "no se creó el respaldo:\n#{out}")
  if bundle
    vout, vst = run("ruby", copy.join("tools/kos_backup.rb").to_s, "--verify", bundle)
    check(vst.success? && vout.include?("RESTAURACIÓN OK"), "el respaldo no se verificó:\n#{vout}")
    check(vout.include?("Historial de Git: OK"), "el respaldo no guardó el historial de Git:\n#{vout}")
  end
end

if $failures.empty?
  puts "OK — todas las pruebas pasaron."
else
  puts "FALLAS (#{$failures.size}):"
  $failures.each { |f| puts "- #{f}" }
  exit 1
end
