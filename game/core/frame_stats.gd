class_name FrameStats
extends RefCounted
## Registra tempos de quadro e resume FPS, percentis e piores quadros.
## "1% baixo" aqui é o FPS equivalente ao tempo de quadro do percentil 99.

const MAX_SAMPLES := 200000

var samples := PackedFloat32Array()


func record(frame_seconds: float) -> void:
	if samples.size() < MAX_SAMPLES:
		samples.append(frame_seconds)


func reset() -> void:
	samples = PackedFloat32Array()


## Estatísticas dos últimos `count` quadros (para o HUD).
func recent(count: int) -> Dictionary:
	var n := samples.size()
	if n == 0:
		return {}
	return compute(samples.slice(maxi(n - count, 0), n))


func summary() -> Dictionary:
	return compute(samples)


static func compute(frame_times: PackedFloat32Array) -> Dictionary:
	var n := frame_times.size()
	if n == 0:
		return {}
	var sorted := frame_times.duplicate()
	sorted.sort()
	var total := 0.0
	for t in frame_times:
		total += t
	var avg := total / n
	var p99 := percentile(sorted, 0.99)
	var p999 := percentile(sorted, 0.999)
	return {
		"frames": n,
		"avg_fps": 1.0 / avg if avg > 0.0 else 0.0,
		"avg_ms": avg * 1000.0,
		"p50_ms": percentile(sorted, 0.50) * 1000.0,
		"p95_ms": percentile(sorted, 0.95) * 1000.0,
		"p99_ms": p99 * 1000.0,
		"max_ms": sorted[n - 1] * 1000.0,
		"low1_fps": 1.0 / p99 if p99 > 0.0 else 0.0,
		"low01_fps": 1.0 / p999 if p999 > 0.0 else 0.0,
	}


## `sorted` precisa estar em ordem crescente.
static func percentile(sorted: PackedFloat32Array, p: float) -> float:
	if sorted.is_empty():
		return 0.0
	var idx := clampi(int(ceil(p * sorted.size())) - 1, 0, sorted.size() - 1)
	return sorted[idx]
