# encoding: utf-8
# kos_aprobacion.rb — Piezas compartidas de la aprobación de cambios críticos.
# Lo usan tools/kos_pin.rb, tools/kos_aprobar.rb y tools/kos_doctor.rb. Sin IA, solo librería estándar de Ruby.
require "json"
require "openssl"
require "securerandom"
require "digest"
require "time"
require "fileutils"
require "pathname"
require "open3"

module KosAprobacion
  ROOT = Pathname.new(ENV["KOS_ROOT"] || File.join(__dir__, "..", "..")).expand_path
  ESTADO = Pathname.new(ENV["KOS_ESTADO"] || "/var/lib/kos")
  CONFIG = Pathname.new(ENV["KOS_CONFIG"] || "/etc/kos/aprobacion.json")
  VIDA_CODIGO = 900          # el código vence a los 15 minutos
  INTENTOS_POR_SOLICITUD = 3
  FALLOS_GLOBALES = 5        # fallos de PIN/código en una hora y se traba una hora
  PBKDF2_VUELTAS = 200_000

  def self.secreto_path = ESTADO.join("secreto.json")
  def self.log_path = ESTADO.join("aprobaciones.log")
  def self.fallos_path = ESTADO.join("fallos.json")

  def self.leer_json(path, defecto = nil)
    JSON.parse(path.read)
  rescue StandardError
    defecto
  end

  def self.escribir_privado(path, objeto)
    FileUtils.mkdir_p(path.dirname.to_s, mode: 0o700)
    tmp = path.sub_ext(".tmp#{$$}")
    File.open(tmp.to_s, "w", 0o600) { |f| f.write(JSON.pretty_generate(objeto)) }
    File.rename(tmp.to_s, path.to_s)
  end

  def self.activa? = secreto_path.file?

  def self.hash_secreto(texto, sal = SecureRandom.hex(16))
    h = OpenSSL::KDF.pbkdf2_hmac(texto.to_s, salt: sal, iterations: PBKDF2_VUELTAS, length: 32, hash: "sha256")
    { "sal" => sal, "hash" => h.unpack1("H*") }
  end

  def self.coincide?(texto, guardado)
    return false unless guardado.is_a?(Hash) && guardado["hash"]
    calculado = hash_secreto(texto, guardado["sal"])["hash"]
    OpenSSL.fixed_length_secure_compare(calculado, guardado["hash"])
  end

  def self.mac(*partes)
    OpenSSL::HMAC.hexdigest("sha256", leer_json(secreto_path, {}).fetch("hmac"), partes.join("|"))
  end

  # Entrada interactiva sin eco. Solo desde una terminal real; KOS_TEST_ENTRADA existe únicamente para las pruebas.
  def self.pedir(mensaje, oculto: true)
    if ENV["KOS_TEST_ENTRADA"]
      @test ||= ENV["KOS_TEST_ENTRADA"].split("\n")
      return @test.shift.to_s
    end
    abort("Esto se hace en una terminal real (SSH al servidor), no desde el chat de una IA.") unless $stdin.tty?
    require "io/console"
    $stderr.print mensaje
    valor = oculto ? $stdin.noecho(&:gets) : $stdin.gets
    $stderr.puts if oculto
    valor.to_s.chomp
  end

  def self.trabado?
    f = leer_json(fallos_path, {})
    recientes = Array(f["fallos"]).select { |t| Time.now - Time.parse(t) < 3600 }
    recientes.size >= FALLOS_GLOBALES ? (Time.parse(recientes.first) + 3600) : nil
  end

  def self.anotar_fallo
    f = leer_json(fallos_path, {})
    recientes = Array(f["fallos"]).select { |t| Time.now - Time.parse(t) < 3600 }
    escribir_privado(fallos_path, "fallos" => recientes + [Time.now.utc.iso8601])
  end

  def self.limpiar_fallos = (fallos_path.delete if fallos_path.file?)

  def self.git(*args, input: nil)
    Open3.capture3("git", "-C", ROOT.to_s, *args, stdin_data: input.to_s, binmode: true)
  end

  def self.aprobados
    return [] unless log_path.file?
    log_path.readlines.filter_map { |l| JSON.parse(l)["commit"] rescue nil }
  end
end
