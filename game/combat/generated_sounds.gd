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


## Parry perfeito: estalo + dois parciais metálicos inarmônicos agudos e longos (o som mais "brilhante").
static func parry_ring(seed_value := 21) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(RATE * 0.45)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := i / float(RATE)
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 90.0)
		var ring := (sin(TAU * 2400.0 * t) * 0.55 + sin(TAU * 3910.0 * t) * 0.35 + sin(TAU * 5230.0 * t) * 0.15) * exp(-t * 7.5)
		var body := sin(TAU * 620.0 * t) * exp(-t * 25.0) * 0.4
		var s := (click * 0.7 + ring * 0.75 + body) * 0.8
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _wav(data)


## Defesa normal: batida metálica grave e curta com baque.
static func block_clank(seed_value := 23) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(RATE * 0.18)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := i / float(RATE)
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 60.0)
		var clank := (sin(TAU * 900.0 * t) * 0.6 + sin(TAU * 1370.0 * t) * 0.3) * exp(-t * 30.0)
		var thump := sin(TAU * 110.0 * t) * exp(-t * 28.0) * 0.8
		var s := (click * 0.6 + clank * 0.6 + thump) * 0.8
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _wav(data)


## Golpe recebido: baque surdo e grave.
static func body_hit(seed_value := 29) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(RATE * 0.22)
	var data := PackedByteArray()
	data.resize(n * 2)
	var low := 0.0
	for i in n:
		var t := i / float(RATE)
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.08
		var thump := sin(TAU * (80.0 + 60.0 * exp(-t * 30.0)) * t) * exp(-t * 16.0)
		var s := (thump * 0.9 + low * 2.5 * exp(-t * 25.0)) * 0.8
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _wav(data)


## Sinal didático do Instrutor: "tic" agudo e curto.
static func cue_tic() -> AudioStreamWAV:
	var n := int(RATE * 0.06)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := i / float(RATE)
		var s := sin(TAU * 2900.0 * t) * exp(-t * 70.0) * 0.6
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _wav(data)


## Cravar: clique metálico curto e mais grave que o sinal do inimigo.
static func posture_lock() -> AudioStreamWAV:
	var n := int(RATE * 0.09)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := i / float(RATE)
		var s := (sin(TAU * 1250.0 * t) * 0.6 + sin(TAU * 1880.0 * t) * 0.25) * exp(-t * 55.0) + sin(TAU * 180.0 * t) * exp(-t * 60.0) * 0.5
		data.encode_s16(i * 2, int(clampf(s * 0.8, -1.0, 1.0) * 32000.0))
	return _wav(data)


## Quebra de postura: estalo seco e queda de tensão elétrica, o som mais grave do combate.
static func posture_break(seed_value := 31) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(RATE * 0.55)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := i / float(RATE)
		phase += TAU * lerpf(400.0, 60.0, clampf(t / 0.5, 0.0, 1.0)) / RATE
		var crack := rng.randf_range(-1.0, 1.0) * exp(-t * 80.0)
		var fall := (sin(phase) * 0.7 + (1.0 if sin(phase) > 0.0 else -1.0) * 0.2) * exp(-t * 4.5)
		data.encode_s16(i * 2, int(clampf((crack * 0.8 + fall) * 0.85, -1.0, 1.0) * 32000.0))
	return _wav(data)


## Cravada: impacto pesado com um toque metálico longo.
static func finish_hit(seed_value := 37) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(RATE * 0.5)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := i / float(RATE)
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 50.0)
		var thump := sin(TAU * (70.0 + 90.0 * exp(-t * 25.0)) * t) * exp(-t * 11.0)
		var ring := (sin(TAU * 1640.0 * t) * 0.5 + sin(TAU * 2710.0 * t) * 0.3) * exp(-t * 8.0)
		data.encode_s16(i * 2, int(clampf((click * 0.6 + thump + ring * 0.4) * 0.8, -1.0, 1.0) * 32000.0))
	return _wav(data)


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
