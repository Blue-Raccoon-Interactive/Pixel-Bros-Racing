
class_name DriftMarkSet
extends Resource

## Conjunto de marcas de pneu de uma superficie.
## A arte fica aqui: para trocar o visual das marcas e so substituir a
## textura neste recurso (ou no .tres que o usa). Nenhum script muda.

## Nome da superficie a que este conjunto pertence.
## Bate com o `surface_name` das zonas de piso (asfalto, grama, terra, neve...).
@export var surface: StringName = &"asphalt"
## Arte da marca de pneu (PNG com transparencia, desenhada no Aseprite).
@export var texture: Texture2D
## Escala da arte: 1.0 = 1 pixel do jogo por pixel da arte.
## Acima de 1 a arte estica e o pixel art borra.
@export_range(0.25, 4.0, 0.05) var pixel_scale: float = 1.0
## Opacidade base da marca.
@export_range(0.0, 1.0, 0.05) var opacity: float = 0.85
