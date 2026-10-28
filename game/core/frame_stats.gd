class_name FrameStats
extends RefCounted
## Registra tempos de quadro e resume FPS, percentis e piores quadros.
## "1% baixo" aqui é o FPS equivalente ao tempo de quadro do percentil 99.

const MAX_SAMPLES := 200000

var samples := PackedFloat32Array()
## Tempo de render medido pelo Godot (ms), do quadro anterior. Independe de limitadores
## de FPS externos, então mostra a folga real da GPU e da CPU.
var gpu_samples := PackedFloat32Array()
var cpu_samples := PackedFloat32Array()


func record(frame_seconds: float, gpu_ms := -1.0, cpu_ms := -1.0) -> void:
	if samples.size() < MAX_SAMPLES:
		samples.append(frame_seconds)
		if gpu_ms >= 0.0:
			gpu_samples.append(gpu_ms)
		if cpu_ms >= 0.0:
			cpu_samples.append(cpu_ms)


func reset() -> void:
	samples = PackedFloat32Array()
	gpu_samples = PackedFloat32Array()
	cpu_samples = PackedFloat32Array()


## Médias e extremos do tempo de render (GPU e CPU) medido pelo Godot.
func render_summary() -> Dictionary:
	var out := {}
	for pair in [["gpu", gpu_samples], ["cpu", cpu_samples]]:
		var arr: PackedFloat32Array = pair[1]
		if arr.is_empty():
			continue
		var sorted := arr.duplicate()
		sorted.sort()
		var total := 0.0
		for v in arr:
			total += v
		out[pair[0] + "_avg_ms"] = total / arr.size()
		out[pair[0] + "_p99_ms"] = percentile(sorted, 0.99)
		out[pair[0] + "_max_ms"] = sorted[sorted.size() - 1]
	return out


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
