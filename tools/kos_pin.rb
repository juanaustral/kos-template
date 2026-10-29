#!/usr/bin/env ruby
# encoding: utf-8
# kos_pin.rb — El titular crea su PIN de aprobación. Se corre una vez, en una terminal real del servidor.
#   ruby tools/kos_pin.rb              crea el PIN y la clave de emergencia (activa la zona crítica)
#   ruby tools/kos_pin.rb --reset      cambia el PIN, con la clave de emergencia
# El PIN no se guarda: solo un hash. La clave de emergencia se muestra una sola vez; guardarla fuera del servidor.
require_relative "lib/kos_aprobacion"
K = KosAprobacion
reset = ARGV.include?("--reset")
actual = K.leer_json(K.secreto_path, nil)

if actual && !reset
  abort "Ya hay un PIN. Para cambiarlo: ruby tools/kos_pin.rb --reset (pide la clave de emergencia)."
end
if reset
  abort "No hay PIN creado todavía." unless actual
  abort "Trabado por intentos fallidos hasta #{K.trabado?.localtime.strftime('%H:%M')}." if K.trabado?
  unless K.coincide?(K.pedir("Clave de emergencia: ").delete("- ").upcase, actual["emergencia"])
    K.anotar_fallo
    abort "Clave de emergencia incorrecta."
  end
end

pin = K.pedir("PIN nuevo (6 a 12 dígitos): ")
abort "El PIN tiene que tener entre 6 y 12 dígitos." unless pin.match?(/\A\d{6,12}\z/)
abort "Ese PIN es demasiado fácil de adivinar." if pin.chars.uniq.size < 3 || "01234567890123456789".include?(pin) || "98765432109876543210".include?(pin)
abort "Los dos PIN no coinciden." unless K.pedir("Repetir el PIN: ") == pin

datos = actual || {
  "hmac" => SecureRandom.hex(32),
  "activado_en_head" => K.git("rev-parse", "HEAD")[0].strip,
  "creado" => Time.now.utc.iso8601
}
datos["pin"] = K.hash_secreto(pin)
emergencia = nil
if actual.nil? || reset
  emergencia = SecureRandom.hex(10).upcase.scan(/.{5}/).join("-")
  datos["emergencia"] = K.hash_secreto(emergencia.delete("-"))
end
K.escribir_privado(K.secreto_path, datos)
K.limpiar_fallos
puts "PIN guardado."
puts "CLAVE DE EMERGENCIA (se muestra una sola vez; guardarla fuera del servidor): #{emergencia}" if emergencia
puts "Desde ahora los cambios críticos (registry/zonas.yaml) piden aprobación con tools/kos_aprobar.rb." if actual.nil?
