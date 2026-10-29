#!/usr/bin/env ruby
# encoding: utf-8
Encoding.default_external = Encoding::UTF_8

# kos_sync.rb — Único proceso que sincroniza KOS con GitHub (pull y push). Lo corre cron cada 5 minutos.
# Los agentes no hacen git pull ni git push: escriben con tools/kos_write.rb y este script sube.
#
# Uso: ruby tools/kos_sync.rb [--simular]
# - Toma el mismo candado que kos_write.rb (nadie escribe mientras sincroniza).
# - Si GitHub tiene commits nuevos y KOS no tiene propios: avanza con --ff-only (nunca pisa cambios sin commitear).
# - Si los dos tienen commits distintos (divergencia): no toca nada y avisa; lo resuelve una persona.
# - Si KOS tiene commits sin subir: push.
# Deja el resultado en .git/kos-sync.json (lo lee kos_doctor.rb). Sale con 1 si algo falló.

require "open3"
require "json"
require "time"
require "pathname"

ROOT = Pathname.new(ENV["KOS_ROOT"] || File.join(__dir__, "..")).expand_path
require_relative "lib/kos_como_servicio"
MODO_ARCHIVO = KosComoServicio.modo_archivo(ROOT)
LOCK_FILE = ROOT.join(".git/kos-write.lock")
STATUS_FILE = ROOT.join(".git/kos-sync.json")
simular = ARGV.include?("--simular")

def git(*args)
  out, err, st = Open3.capture3("git", "-C", ROOT.to_s, *args)
  [out.strip, err.strip, st.success?]
end

def finish(ok, mensaje, extra = {})
  File.write(STATUS_FILE, JSON.pretty_generate({ "fecha" => Time.now.iso8601, "ok" => ok, "mensaje" => mensaje }.merge(extra)))
  File.chmod(MODO_ARCHIVO, STATUS_FILE) rescue nil
  puts "#{Time.now.strftime("%F %T")} #{ok ? "OK" : "ERROR"} #{mensaje}"
  exit(ok ? 0 : 1)
end

File.open(LOCK_FILE, File::RDWR | File::CREAT, MODO_ARCHIVO) do |lock|
  File.chmod(MODO_ARCHIVO, LOCK_FILE) rescue nil
  deadline = Time.now + 60
  until lock.flock(File::LOCK_EX | File::LOCK_NB)
    finish(false, "KOS ocupado más de 60 s; se reintenta en la próxima vuelta") if Time.now > deadline
    sleep 0.5
  end

  branch, = git("rev-parse", "--abbrev-ref", "HEAD")
  finish(false, "KOS no está en main (está en #{branch})") unless branch == "main"
  _, err, ok = git("fetch", "-q", "origin", "main")
  finish(false, "fetch falló: #{err[0, 200]}") unless ok

  ahead = git("rev-list", "--count", "origin/main..HEAD")[0].to_i
  behind = git("rev-list", "--count", "HEAD..origin/main")[0].to_i
  stats = { "adelante" => ahead, "atras" => behind }
  finish(true, "simulación: #{ahead} para subir, #{behind} para bajar", stats) if simular

  if behind.positive? && ahead.positive?
    finish(false, "KOS y GitHub divergieron (#{ahead} locales, #{behind} remotos): requiere intervención", stats)
  end
  if behind.positive?
    _, err, ok = git("merge", "--ff-only", "-q", "origin/main")
    finish(false, "no se pudo traer lo de GitHub (cambios sin commitear en los mismos archivos): #{err[0, 200]}", stats) unless ok
  end
  if ahead.positive?
    pushed = false
    3.times do |i|
      _, err, pushed = git("push", "-q", "origin", "main")
      break if pushed
      sleep 2**(i + 1)
    end
    finish(false, "push falló: #{err[0, 200]}", stats) unless pushed
  end
  finish(true, ahead.zero? && behind.zero? ? "al día" : "subidos #{ahead}, bajados #{behind}", stats)
end
