# Rastros de pneu (drift marks)

Guia de quem vai **desenhar** e **ajustar** as marcas de pneu do Pixel Bros Racing.

---

## 1. Como funciona em 30 segundos

1. O `Kart` (scripts/Kart.gd) olha o próprio movimento a cada frame de física.
2. Se o movimento é "derrapagem", o kart pede uma marca para **cada pneu traseiro**.
3. As marcas vão para o nó `DriftMarks`, que fica **na cena** (irmão do kart), e
   não dentro do kart. Por isso elas ficam no chão: não andam com o carro nem
   com a câmera.
4. Cada marca é um `Sprite2D` pequeno com a arte do Aseprite, desenhada 1:1
   (sem escala, sem blur). Os sprites são reaproveitados: nada é criado ou
   destruído a cada frame.

```text
Main (cena da corrida)
├── pista (TileMapLayer do chão)
├── DriftMarks          <- container das marcas (no mundo)
└── Kart
    ├── AnimatedSprite2D (o kart 32x32)
    ├── RearWheelLeft   <- âncora do pneu traseiro esquerdo
    └── RearWheelRight  <- âncora do pneu traseiro direito
```

---

## 2. Onde trocar a arte (sem mexer em script)

```text
assets/effects/drift/
├── asphalt/skid_mark.png   <- arte do asfalto
├── dirt/skid_mark.png      <- arte da terra
├── grass/skid_mark.png     <- arte da grama
├── snow/skid_mark.png      <- arte da neve
├── mark_set_asphalt.tres   <- liga a arte à superfície "asphalt"
├── mark_set_dirt.tres
├── mark_set_grass.tres
├── mark_set_snow.tres
└── kart_wheel_anchors.tres <- posição dos pneus traseiros de cada kart
```

**Trocar a arte**: sobrescreva o PNG com o mesmo nome e pronto. Não precisa
mexer em script nem em cena.

**Trocar o comportamento da arte** (escala, opacidade): edite o `.tres`
correspondente no inspetor do Godot.

| Propriedade do `DriftMarkSet` | Para que serve |
|---|---|
| `surface` | Nome da superfície (`asphalt`, `grass`, `dirt`, `snow`...). |
| `texture` | A arte (PNG com transparência). |
| `pixel_scale` | 1.0 = 1 pixel do jogo por pixel da arte. Acima de 1 a arte estica e o pixel art borra. |
| `opacity` | Opacidade base da marca. |

---

## 3. Como exportar do Aseprite sem perder a qualidade

1. No Aseprite, a arte da marca deve ser **pequena** (4x10 px ou 6x12 px):
   é um pedaço de pneu, não um sprite de 32x32.
2. **File → Export As PNG** (ou `Ctrl+Shift+Alt+S`).
3. Salve por cima do arquivo em `assets/effects/drift/<superficie>/skid_mark.png`.
4. Volte para o Godot: a textura é reimportada sozinha (ou clique com o botão
   direito em `skid_mark.png → Reimport`).

Cuidados para o pixel art:

- **Sem mipmap.** O projeto já importa sem mipmap (`mipmaps/generate=false`).
- **Filtro nearest.** O projeto já está com `textures/canvas_textures/default_texture_filter=0`
  (nearest) e o `DriftMarks` força nearest nos filhos.
- **Sem metade de pixel.** A arte deve ter tamanho **par** (ex.: 4x10), senão
  o sprite fica entre dois pixels e a marca "cintila" quando o carro vira.
- **Alfa no próprio PNG**, sem fundo chapado: a marca precisa deixar o chão
  aparecer.

---

## 4. Ajustes do sistema

### `scenes/effects/drift_marks.tscn` (container das marcas)

| Propriedade | Padrão | Para que serve |
|---|---|---|
| `max_marks` | 600 | Limite de marcas vivas. As mais antigas são recicladas. |
| `mark_lifetime` | 6 s | Tempo que a marca fica no chão. `0` = permanente. |
| `fade_duration` | 2 s | Tempo em que a marca vai ficando transparente no fim da vida. |
| `rotation_steps` | 0 | Passos de rotação da marca. `0` = rotação livre; `16`/`32` deixa o visual mais pixelado. |
| `orientation_mode` | `VEHICLE` | `VEHICLE` = a marca acompanha a orientação do kart (o desenho do pneu). `TRAVEL` = a marca acompanha o caminho do pneu e o rastro sai contínuo. |
| `mark_sets` | 4 conjuntos | Lista de `DriftMarkSet` (uma por superfície). |

### `scripts/drift_detector.gd` (quando é derrapagem)

| Propriedade | Padrão | Para que serve |
|---|---|---|
| `min_speed` | 140 px/s | Velocidade mínima para gerar marcas. |
| `min_slip_angle_degrees` | 18° | Ângulo entre a direção do kart e a direção do movimento. |
| `min_lateral_slip` | 70 px/s | Deslizamento lateral do kart. |
| `min_hard_steer` | 0.8 | Esterço mínimo para contar como "curva fechada". |
| `min_hard_steer_speed` | 240 px/s | Velocidade mínima para a curva fechada valer. |

### No kart (inspetor do `Kart`)

| Propriedade | Padrão | Para que serve |
|---|---|---|
| `drift_mark_spacing` | 8 px | Distância entre uma marca e a seguinte de cada pneu. |
| `drift_default_surface` | `asphalt` | Superfície usada fora de qualquer zona de piso. |
| `drift_detector` | (vazio) | Se você colocar um `DriftDetector` aqui, ele vale para o kart. |
| `wheel_anchors` | (vazio) | Tabela com a posição dos pneus traseiros de cada kart. |

> A distância entre as marcas deve ser **igual ou um pouco menor** que a
> altura da arte (10 px na arte de exemplo, 8 px de espaçamento) para o
> rastro não ficar com buracos.

---

## 5. Superfícies (asfalto, grama, terra, neve)

O sistema reaproveita as **zonas de piso** que já existiam no jogo
(`scripts/grass_zone.gd`). Cada zona tem agora um campo `surface_name`:

| Zona | `surface_name` | Efeito |
|---|---|---|
| Asfalto (sem zona) | `asphalt` (padrão do kart) | Marca escura no asfalto. |
| `grass_zone.tscn` | `grass` | Marca de grama. |
| Zona de terra | `dirt` | Marca de terra. |
| Zona de neve | `snow` | Marca de neve. |

Para criar uma zona de terra: arraste `scenes/tracks/grass_zone.tscn` para a
pista, desenhe o `CollisionPolygon2D` e troque `surface_name` para `dirt`
(deixe `multiplier` em 1.0 se a terra não deve deixar o kart mais lento).

---

## 6. Pneus traseiros de cada kart

Cada kart tem um desenho diferente (o "Esportivo F1" é bem mais estreito que o
"Fuguete"), então a posição dos pneus traseiros é medida kart por kart em
`assets/effects/drift/kart_wheel_anchors.tres`.

O kart usa a âncora nesta ordem:

1. Marcadores `RearWheelLeft` e `RearWheelRight` na cena do kart (se existirem);
2. A tabela `kart_wheel_anchors.tres` (pelo `kart_name` do kart);
3. Os valores `rear_wheel_left` / `rear_wheel_right` do inspetor.

Se a arte dos karts mudar, meca de novo e regenere a tabela:

```powershell
godot --headless --path . --script res://tools/apply_drift_setup.gd
```

As medidas ficam no começo do arquivo `tools/apply_drift_setup.gd`
(`WHEEL_MEASURES`), em coordenadas de pixel do sprite.

---

## 7. Como testar

### Teste automático (sem abrir o jogo)

```powershell
godot --headless --path . --script res://tools/test_drift_marks.gd
```

Ele confere: linha reta sem marcas, curva normal sem marcas, drift com dois
rastros, espaçamento constante, marcas sob os pneus, marcas que ficam no
lugar quando o carro anda, sumiço das marcas antigas e o limite de marcas.

### Teste manual

1. Abra `scenes/race.tscn` (F6) e escolha um kart no menu antes.
2. Segure `W` (acelerar) e vire com `A`/`D` em velocidade alta: o kart deve
   deslizar e deixar dois rastros.
3. Solte o acelerador: as marcas param de nascer.
4. Espere alguns segundos: as marcas mais antigas somem.

---

## 8. Limitações conhecidas

- **A física do jogo importa.** O `Kart` não desliza de verdade em baixa
  velocidade: o `grip` (aderência lateral) apaga o deslizamento. Por isso o
  detector tem o critério de "curva fechada", para o drift aparecer também
  abaixo da velocidade em que o kart realmente escorrega.
- **A âncora dos pneus é medida, não automática.** Se o desenho do kart mudar
  de tamanho, meca de novo (seção 6).
- **As marcas não decai por bioma ainda.** Hoje a arte é a mesma para toda a
  volta da pista; as zonas de grama/terra/neve já escolhem a arte certa.
