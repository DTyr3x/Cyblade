class_name GeneratedSounds
extends RefCounted
## Sons provisórios SINTETIZADOS em código (ruído filtrado e senoides). São originais: não há
## arquivo de áudio de terceiros, logo não há licença a verificar. Servem só para dar retorno
## ao golpe e ao contato até existirem sons de verdade (ver docs/ativos/registro.md).

const RATE := 22050


## Corte no ar: ruído com passa-banda que sobe e desce (whoosh). `pitch` desloca o timbre.
static func swish(duration := 0.22, pitch := 1.0, seed_value := 7) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := i / float(n)
		var env := sin(PI * t) * (1.0 - t * 0.35)
		var noise := rng.randf_range(-1.0, 1.0)
		# Filtro de um polo cuja frequência sobe até o meio do golpe.
		var coef := clampf((0.08 + 0.5 * sin(PI * t)) * pitch, 0.02, 0.9)
		low += (noise - low) * coef
		band += (low - band) * coef
		var s := (low - band) * 3.2 * env * 0.7
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _wav(data)


## Contato de lâmina: estalo de ruído + toque metálico que decai. `heavy` = mais grave e longo.
static func impact(heavy := false, seed_value := 11) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var duration := 0.32 if heavy else 0.2
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var f1 := 520.0 if heavy else 880.0
	var f2 := f1 * 2.71
	for i in n:
		var t := i / float(RATE)
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * (38.0 if heavy else 70.0))
		var ring := (sin(TAU * f1 * t) * 0.6 + sin(TAU * f2 * t) * 0.35) * exp(-t * (14.0 if heavy else 22.0))
		var thump := sin(TAU * 90.0 * t) * exp(-t * 20.0) * (0.9 if heavy else 0.3)
		var s := (click * 0.8 + ring * 0.55 + thump) * 0.8
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _wav(data)


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
