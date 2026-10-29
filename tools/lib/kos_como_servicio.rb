# encoding: utf-8
# kos_como_servicio.rb — Si la carpeta de KOS es del usuario `kos`, todo el que escribe lo hace como `kos`
# (único dueño). La línea de comandos es la misma para cualquier IA o persona: el script se relanza solo con sudo.
# Si KOS no es de `kos` (pruebas, otra instalación), no hace nada.
require "etc"
require "rbconfig"
module KosComoServicio
  def self.kos = (Etc.getpwnam("kos") rescue nil)

  # Modo de los archivos que crean las herramientas: sin escritura de grupo si KOS está cerrado.
  def self.modo_archivo(raiz) = cerrado?(raiz) ? 0o644 : 0o664

  def self.cerrado?(raiz)
    k = kos
    !!(k && File.stat(raiz.to_s).uid == k.uid)
  end

  # Cosas que alguien corrió como root (un commit a mano, por ejemplo) quedan de root y trabarían a `kos`: se devuelven a `kos`.
  def self.normalizar_dueno(raiz)
    return unless Process.uid.zero? && cerrado?(raiz)
    system("find", raiz.to_s, "(", "-path", File.join(raiz.to_s, "backups"), "-o", "-path", File.join(raiz.to_s, "exports"), ")", "-prune", "-o",
           "!", "-user", "kos", "-exec", "chown", "-h", "kos:kos", "{}", "+", out: File::NULL, err: File::NULL)
  end

  RUBY = File.executable?("/usr/bin/ruby") ? "/usr/bin/ruby" : RbConfig.ruby # la ruta exacta que autoriza sudoers

  def self.relanzar(script, raiz, comando: [RUBY])
    return unless cerrado?(raiz)
    File.umask(0o022) # lo que se cree nace sin escritura de grupo ni de otros, sea cual sea la umask de quien llama
    return if Process.uid == kos.uid
    normalizar_dueno(raiz)
    args = ARGV.dup
    entrada = nil
    if (i = args.index("--archivo")) && args[i + 1] && args[i + 1] != "-"
      begin
        entrada = File.binread(args[i + 1]) # se lee con los permisos de quien llama; `kos` no tiene por qué verlo
      rescue SystemCallError => e
        abort "No puedo leer #{args[i + 1]}: #{e.message}"
      end
      args[i + 1] = "-"
    end
    cmd = ["sudo", "-n", "-u", "kos", "--", *comando, script, *args]
    if entrada
      IO.popen(cmd, "w") { |io| io.write(entrada) }
      exit($?.exitstatus || 1)
    else
      exec(*cmd)
    end
  end
end
