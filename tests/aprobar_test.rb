#!/usr/bin/env ruby
# encoding: utf-8
# Prueba de la aprobación por email, en un KOS descartable. Intenta los engaños que importan.
require "tmpdir"
require "open3"
require "fileutils"
require "json"
require "time"
raiz = File.expand_path("..", __dir__)
fallas = []
Dir.mktmpdir("kos-aprob-test") do |t|
  kos = File.join(t, "kos"); estado = File.join(t, "estado"); correo = File.join(t, "mail.txt")
  FileUtils.mkdir_p(kos)
  Dir.chdir(kos) do
    system("git", "init", "-q", "-b", "main", ".")
    %w[user.name user.email].each { |k| system("git", "config", k, "t") }
    system("rsync", "-rl", "--exclude", ".git", "--exclude", "backups", "--exclude", "exports", "--exclude", "__pycache__", "#{raiz}/", "#{kos}/")
    system("git", "add", "-A"); system("git", "commit", "-q", "-m", "base")
  end
  cfg = File.join(t, "cfg.json"); File.write(cfg, JSON.generate("destinatario" => "titular@test", "correo_env" => "/dev/null"))
  env = { "KOS_ROOT" => kos, "KOS_ESTADO" => estado, "KOS_CONFIG" => cfg, "KOS_CORREO" => correo }
  run = ->(args, entrada = nil, extra = {}) do
    e = env.merge(extra); e["KOS_TEST_ENTRADA"] = entrada if entrada
    Open3.capture2e(e, "ruby", File.join(kos, "tools", args.shift), *args)
  end
  # 1. antes del PIN no se puede pedir
  out, st = run.call(%w[kos_aprobar.rb estado])
  fallas << "estado sin PIN" unless out.include?("sin activar")
  # 2. PIN débil y distinto
  _, st = run.call(%w[kos_pin.rb], "111111\n111111")
  fallas << "aceptó PIN débil" if st.success?
  _, st = run.call(%w[kos_pin.rb], "482913\n482914")
  fallas << "aceptó PIN que no coincide" if st.success?
  out, st = run.call(%w[kos_pin.rb], "482913\n482913")
  fallas << "no creó el PIN: #{out}" unless st.success? && out.include?("CLAVE DE EMERGENCIA")
  emergencia = out[/EMERGENCIA[^:]*: (\S+)/, 1]
  fallas << "el PIN quedó en claro en el servidor" if File.read(File.join(estado, "secreto.json")).include?("482913")
  fallas << "secreto.json con permisos abiertos" unless (File.stat(File.join(estado, "secreto.json")).mode & 0o077).zero?
  # 3. patch que modifica AGENTS.md
  patch = File.join(t, "c.diff")
  File.write(File.join(kos, "AGENTS.md"), File.read(File.join(kos, "AGENTS.md")) + "\nregla dos\n")
  File.write(patch, `git -C #{kos} diff`); system("git", "-C", kos, "checkout", "-q", "AGENTS.md")
  out, st = run.call(["kos_aprobar.rb", "solicitar", "--descripcion", "agregar regla dos", "--patch", patch])
  fallas << "no envió la solicitud: #{out}" unless st.success?
  id = out[/Solicitud (\h+)/, 1]
  mail = File.read(correo)
  codigo = mail[/Código: (\d{6})/, 1]
  fallas << "el mail no trae el cambio" unless mail.include?("+regla dos") && mail.include?("Para: titular@test")
  fallas << "la IA vio el código en la salida de solicitar" if out.include?(codigo.to_s)
  # 4. engaños
  _, st = run.call(["kos_aprobar.rb", "aplicar", "--id", id], "#{codigo}\n000000")
  fallas << "aceptó PIN equivocado" if st.success?
  _, st = run.call(["kos_aprobar.rb", "aplicar", "--id", id], "999999\n482913")
  fallas << "aceptó código equivocado" if st.success?
  File.binwrite(File.join(estado, "pend-#{id}.carga"), File.binread(File.join(estado, "pend-#{id}.carga")).sub("regla dos", "regla MALA"))
  out, st = run.call(["kos_aprobar.rb", "aplicar", "--id", id], "#{codigo}\n482913")
  fallas << "aplicó un cambio alterado después de pedirlo" if st.success?
  fallas << "la solicitud alterada sigue viva" if File.exist?(File.join(estado, "pend-#{id}.json"))
  # 5. camino feliz con solicitud nueva
  out, = run.call(["kos_aprobar.rb", "solicitar", "--descripcion", "agregar regla dos", "--patch", patch])
  id = out[/Solicitud (\h+)/, 1]; codigo = File.read(correo)[/Código: (\d{6})/, 1]
  _, st = run.call(["kos_aprobar.rb", "aplicar", "--id", id], "#{codigo}\n482913")
  fallas << "no aplicó con código y PIN correctos" unless st.success?
  fallas << "el cambio no quedó commiteado con la aprobación" unless `git -C #{kos} log -1 --format=%B`.include?("Aprobado-por: titular (solicitud #{id})") && File.read(File.join(kos, "AGENTS.md")).include?("regla dos")
  # 6. reuso
  _, st = run.call(["kos_aprobar.rb", "aplicar", "--id", id], "#{codigo}\n482913")
  fallas << "dejó reusar la aprobación" if st.success?
  # 7. vencida
  out, = run.call(["kos_aprobar.rb", "solicitar", "--descripcion", "otra", "--comando", "echo hola"])
  id2 = out[/Solicitud (\h+)/, 1]; cod2 = File.read(correo)[/Código: (\d{6})/, 1]
  pf = File.join(estado, "pend-#{id2}.json"); j = JSON.parse(File.read(pf)); j["vence"] = (Time.now - 5).utc.iso8601; File.write(pf, JSON.generate(j))
  _, st = run.call(["kos_aprobar.rb", "aplicar", "--id", id2], "#{cod2}\n482913")
  fallas << "aceptó un código vencido" if st.success?
  # 8. sin terminal ni entrada de prueba
  out, = run.call(["kos_aprobar.rb", "solicitar", "--descripcion", "x", "--comando", "echo x"])
  id3 = out[/Solicitud (\h+)/, 1]
  _, st = Open3.capture2e(env, "ruby", File.join(kos, "tools/kos_aprobar.rb"), "aplicar", "--id", id3, stdin_data: "")
  fallas << "aplicó sin terminal" if st.success?
  # 9. el doctor marca el cambio crítico sin aprobación y deja pasar el aprobado
  base = `git -C #{kos} rev-list --max-parents=0 HEAD`.strip # la vigilancia mira desde la base: incluye el cambio aprobado y el directo
  File.write(File.join(kos, ".git/kos-vigia.json"), JSON.generate("head" => base))
  File.write(File.join(kos, "tools/kos_sync.rb"), "# toque directo\n"); system("git", "-C", kos, "add", "-A"); system("git", "-C", kos, "commit", "-q", "-m", "toque directo de una IA")
  out, = Open3.capture2e(env, "ruby", File.join(kos, "tools/kos_doctor.rb"))
  fallas << "el doctor no marcó el cambio crítico sin aprobación: #{out}" unless out.include?("cambio crítico sin aprobación") && out.include?("toque directo")
  fallas << "el doctor marcó el cambio aprobado" if out.include?("agregar regla dos")
  # 10. reset del PIN con la clave de emergencia
  _, st = run.call(%w[kos_pin.rb --reset], "CLAVE-MALA\n482913\n482913")
  fallas << "aceptó clave de emergencia falsa" if st.success?
  _, st = run.call(%w[kos_pin.rb --reset], "#{emergencia}\n731904\n731904")
  fallas << "no dejó resetear con la clave de emergencia" unless st.success?
end
if fallas.empty? then puts "aprobar_test: OK"; exit 0
else puts "aprobar_test FALLÓ:\n- #{fallas.join("\n- ")}"; exit 1 end
