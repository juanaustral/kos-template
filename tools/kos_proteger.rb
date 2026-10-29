#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8
ARGV.map! { |a| a.dup.force_encoding(Encoding::UTF_8) }
# kos_proteger.rb — Cierra tu KOS en un servidor Linux: lo hace propiedad de un usuario de servicio (`kos`) y deja que las IA
# escriban solo por tools/kos_write.rb (que se relanza solo como `kos` con sudo). Es lo que lleva la protección al nivel 3.
#
#   ruby tools/kos_proteger.rb --agentes ana,bot            muestra qué haría; no cambia nada
#   sudo ruby tools/kos_proteger.rb --agentes ana,bot --cerrar    lo aplica (requiere root)
#   sudo ruby tools/kos_proteger.rb --abrir                 vuelta atrás, con la foto de permisos que se guardó antes de cerrar
#
# --agentes: usuarios del sistema con los que trabajan tus IA (no root). Entran al grupo `kosagentes`, que solo puede
# ejecutar kos_write.rb, kos_skills.rb (los comandos que escriben) y kos_doctor.rb como `kos`: nada más.
# Después: corre tus sesiones de IA con ese usuario (no root) y comprueba con `ruby tools/kos_proteccion.rb nivel`.
# Requisitos: Linux, root, sudo. Los cron de sync y doctor siguen corriendo como root: así las llaves de GitHub no salen de root.
require "optparse"
require "pathname"
require "open3"
require "fileutils"
require "time"
require_relative "lib/kos_como_servicio"

ROOT = Pathname.new(ENV["KOS_ROOT"] || File.join(__dir__, "..")).expand_path
ENV["PATH"] = "#{ENV["PATH"]}:/usr/sbin:/sbin"
opts = { servicio: "kos", grupo: "kosagentes", agentes: [] }
OptionParser.new do |o|
  o.on("--agentes LISTA") { |v| opts[:agentes] = v.split(",").map(&:strip).reject(&:empty?) }
  o.on("--cerrar") { opts[:cerrar] = true }
  o.on("--abrir") { opts[:abrir] = true }
  o.on("--ayuda") { puts File.read(__FILE__)[/\A.*?^require/m].lines.grep(/\A#/).map { |l| l.sub(/\A# ?/, "") }.join; exit }
end.parse!
FOTO = Pathname.new(ENV["KOS_ESTADO"] || "/var/lib/kos").join("foto-permisos.txt")
SUDOERS = Pathname.new(ENV["KOS_SUDOERS_DIR"] || "/etc/sudoers.d").join("kos-agentes")
EXCLUIDOS = %w[backups exports].map { |d| ROOT.join(d).to_s }

def sh(*cmd) = Open3.capture2e(*cmd)
def paso(texto) = puts("  - #{texto}")
def sin_excluidos = ["find", ROOT.to_s, "(", *EXCLUIDOS.flat_map { |e| ["-path", e, "-o"] }.tap(&:pop), ")", "-prune", "-o"]

abort "Solo funciona en Linux." unless RUBY_PLATFORM.include?("linux")
abort "Falta tools/lib/kos_como_servicio.rb: ¿es un KOS completo?" unless ROOT.join(".git").exist?
ruby_bin = File.executable?("/usr/bin/ruby") ? "/usr/bin/ruby" : abort("Hace falta ruby en /usr/bin/ruby (es la ruta exacta que autoriza sudoers).")

sudoers = <<~SUDO
  # #{SUDOERS} — KOS cerrado: quién puede escribir y cómo. Solo como el usuario `#{opts[:servicio]}` y solo con estas herramientas.
  # Sin argumentos y con argumentos son dos entradas distintas para sudoers.
  Cmnd_Alias KOS_HERRAMIENTAS = #{ruby_bin} #{ROOT}/tools/kos_write.rb, #{ruby_bin} #{ROOT}/tools/kos_write.rb *, \\
      #{ruby_bin} #{ROOT}/tools/kos_doctor.rb, #{ruby_bin} #{ROOT}/tools/kos_doctor.rb *, \\
      #{ruby_bin} #{ROOT}/tools/kos_skills.rb *
  Defaults:%#{opts[:grupo]} env_keep += "KOS_AGENTE"
  Defaults:%#{opts[:grupo]} umask=0022, umask_override
  %#{opts[:grupo]} ALL=(#{opts[:servicio]}) NOPASSWD: KOS_HERRAMIENTAS
SUDO

if opts[:abrir]
  abort "Hace falta ser root." unless Process.uid.zero?
  abort "No hay foto de permisos (#{FOTO}): no sé a qué estado volver." unless FOTO.file?
  FOTO.each_line do |l|
    next if l.start_with?("#")
    modo, dueno, ruta = l.chomp.split(" ", 3)
    next if File.symlink?(ruta) || !File.exist?(ruta)
    sh("chown", "-h", dueno, ruta); sh("chmod", modo, ruta)
  end
  compartido = FOTO.read[/^# sharedRepository: (\S+)/, 1]
  sh("git", "-C", ROOT.to_s, "config", "core.sharedRepository", compartido) if compartido && compartido != "-"
  SUDOERS.delete if SUDOERS.file?
  puts "KOS vuelve al modo anterior (permisos de la foto del #{FOTO.mtime.strftime('%Y-%m-%d %H:%M')})."
  exit
end

puts(opts[:cerrar] ? "Cerrando KOS en #{ROOT}:" : "Esto haría (agregá --cerrar para aplicarlo):")
paso "foto de los permisos actuales en #{FOTO} (para poder volver con --abrir)"
paso "usuario de servicio `#{opts[:servicio]}` y grupo `#{opts[:grupo]}` (si no existen)"
paso "usuarios de IA al grupo: #{opts[:agentes].empty? ? "(ninguno: indicá --agentes usuario1,usuario2)" : opts[:agentes].join(", ")}"
paso "sudoers mínimo en #{SUDOERS}, validado con visudo antes de activarse"
paso "KOS pasa a ser de `#{opts[:servicio]}`, sin escritura de grupo ni de otros; core.sharedRepository se quita"
paso "tools/kos_doctor.rb --arreglar deja todo en orden"
puts "Nota: las sesiones de IA tienen que correr con uno de esos usuarios, no con root: root se saltea todo lo anterior." if opts[:agentes].any?
exit unless opts[:cerrar]

abort "Hace falta ser root (sudo ruby tools/kos_proteger.rb --cerrar ...)." unless Process.uid.zero?
abort "Indicá al menos un usuario de IA con --agentes (no uses root)." if opts[:agentes].empty? || opts[:agentes].include?("root")
opts[:agentes].each { |u| abort "El usuario #{u} no existe." unless sh("id", u)[1].success? }
abort "KOS ya está cerrado." if KosComoServicio.cerrado?(ROOT)

FileUtils.mkdir_p(FOTO.dirname.to_s, mode: 0o700)
foto, = sh(*sin_excluidos, "-printf", "%m %u:%g %p\n")
compartido = sh("git", "-C", ROOT.to_s, "config", "core.sharedRepository")[0].strip
File.open(FOTO.to_s, "w", 0o600) { |f| f.puts "# sharedRepository: #{compartido.empty? ? "-" : compartido}"; f.write(foto) }
sh("useradd", "-r", "-M", "-d", ROOT.to_s, "-s", "/usr/sbin/nologin", opts[:servicio]) unless sh("id", opts[:servicio])[1].success?
sh("groupadd", opts[:grupo]) unless sh("getent", "group", opts[:grupo])[1].success?
opts[:agentes].each { |u| sh("usermod", "-aG", opts[:grupo], u) }
nuevo = Pathname.new("#{SUDOERS}.nuevo") # con punto en el nombre, sudo lo ignora hasta que se valida
File.write(nuevo.to_s, sudoers); File.chmod(0o440, nuevo.to_s)
out, st = sh("visudo", "-cf", nuevo.to_s)
(nuevo.delete; abort "El sudoers generado no es válido; no se cambió nada más.\n#{out}") unless st.success?
File.rename(nuevo.to_s, SUDOERS.to_s)
sh("git", "-C", ROOT.to_s, "config", "--unset", "core.sharedRepository")
sh(*sin_excluidos, "-exec", "chown", "-h", "#{opts[:servicio]}:#{opts[:servicio]}", "{}", "+")
sh(*sin_excluidos, "-type", "d", "-exec", "chmod", "755", "{}", "+")
sh(*sin_excluidos, "-type", "f", "-exec", "chmod", "go-w", "{}", "+")
out, = sh(ruby_bin, ROOT.join("tools/kos_doctor.rb").to_s, "--arreglar")
puts out unless out.strip == "KOS: todo bien."
puts "Listo. Comprobá como uno de tus usuarios de IA: ruby #{ROOT}/tools/kos_proteccion.rb nivel (y `ataque`). Vuelta atrás: sudo ruby #{ROOT}/tools/kos_proteger.rb --abrir"
