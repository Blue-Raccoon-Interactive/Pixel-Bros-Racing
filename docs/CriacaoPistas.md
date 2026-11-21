# Como montar uma pista

Guia para quem desenha as pistas do Pixel Bros Racing. Voce **nao precisa mexer em codigo**.

## Regra principal

**Nunca edite o `track_base.tscn`.** Ele e o molde. Toda pista nova e uma **cena herdada** dele.

## 1. Criar a pista

1. Menu **Cena -> Nova cena herdada...**
2. Escolha `res://scenes/tracks/track_base.tscn`.
3. Salve como `res://scenes/tracks/track_02.tscn` (siga o nome: `track_` + numero).
4. Renomeie o no raiz para `Track02`.
5. No inspetor da raiz, ajuste **Track Name** e **Laps** (numero de voltas).

## 2. O que tem no molde

```text
TrackBase
├── Environment
│   ├── Grass        (TileMapLayer: chao de grama)
│   ├── Road         (TileMapLayer: asfalto)
│   └── Decoration   (Node2D: enfeites)
├── Collisions
│   └── Walls        (StaticBody2D: paredes)
├── SurfaceZones     (zonas de grama: deixam o kart mais lento)
├── Checkpoints      (checkpoints da corrida, em ordem)
├── Waypoints        (reservado para a IA, ainda nao usado)
└── StartPositions   (onde os karts comecam)
```

Nos que vem do molde **nao podem ser apagados** na pista filha. Voce so adiciona coisas dentro deles.

## 3. Montar a pista

### Chao

Pinte `Grass` e `Road` com os tiles do TileSet (se for usa, caso for usa imagem ignore).

### Paredes

1. Selecione `Collisions/Walls`.
2. Adicione filhos **CollisionPolygon2D** e desenhe o contorno no editor.
3. O triangulo amarelo de aviso em `Walls` some quando houver pelo menos uma forma.

### Zonas de grama

O kart so fica mais lento onde existe uma **zona de grama**. Pintar o tile de grama nao basta: cubra com zonas toda area fora do asfalto onde o kart pode ir.

1. Arraste `scenes/tracks/grass_zone.tscn` para dentro de `SurfaceZones`.
2. Selecione a zona e adicione um filho **CollisionPolygon2D**. Desenhe o contorno da area de grama.
3. O triangulo amarelo na zona some quando ela tiver uma forma.
4. No inspetor, **Multiplier** define a lentidao: `0.6` = 60% da velocidade maxima (menor numero = mais lento).
5. Zonas vizinhas ou sobrepostas funcionam bem juntas: vale a mais lenta.

### Checkpoints

1. Arraste `scenes/race/checkpoint.tscn` para dentro de `Checkpoints`.
2. **A ordem na arvore e a ordem da corrida.** O primeiro checkpoint e a **linha de largada**: o kart precisa passar por ele, depois pelos seguintes, e voltar a cruza-lo para fechar uma volta.
3. Posicione e gire cada checkpoint para ficar **atravessando a pista inteira**, de parede a parede. Assim o kart nao consegue desviar dele.
4. Use pelo menos 3 ou 4 checkpoints bem espalhados, para impedir atalhos.

### Posicao de largada

1. Dentro de `StartPositions` ha um `Marker2D`. Mova-o para a linha de largada.
2. **Rotacao 0 = kart olhando para cima.** Gire o marcador se a pista comecar em outra direcao.
3. Para uma grade de largada, duplique o marcador (um por kart).

## 4. Avisos no editor

Se faltar algo importante, o no raiz da pista mostra um **triangulo amarelo**. Passe o mouse e leia a mensagem (por exemplo: "Adicione pelo menos um checkpoint").

## 5. Testar a pista

Voce nao precisa de programador para rodar sua pista:

1. **Cena -> Nova cena herdada...** e escolha `res://scenes/race/race.tscn`.
2. Salve como `res://scenes/debug/teste_track_02.tscn` (o nome da sua pista).
3. Selecione a raiz e, no inspetor, em **Track Scene**, escolha a sua pista.
4. Aperte **F6** (rodar a cena atual).

O kart nasce no primeiro `Marker2D` de `StartPositions`, a contagem comeca e as voltas contam pelos checkpoints, na ordem da arvore.

**Nao edite o `race.tscn` para testar.** Use sempre a sua cena de teste herdada, para nao gerar conflito com o trabalho dos programadores.

## 6. Checklist antes de commitar

- [ ] Pista salva em `scenes/tracks/` como cena herdada de `track_base`
- [ ] Testada com a cena de teste herdada de `race.tscn` (F6)
- [ ] Nenhum triangulo amarelo na raiz
- [ ] Paredes fecham a pista toda (o kart nao sai do mapa)
- [ ] Zonas de grama cobrem as areas fora do asfalto onde o kart consegue ir
- [ ] Checkpoints na ordem certa, atravessando a pista de lado a lado
- [ ] Primeiro checkpoint na linha de largada
- [ ] `Marker2D` de largada posicionado e girado

## Ainda nao disponivel

Estas partes estao previstas, mas dependem dos programadores:

- **Escolher a pista pelo menu do jogo:** por enquanto o menu ainda abre uma cena de teste. Para ver sua pista, use a cena de teste herdada (secao 5).
- **`Waypoints`:** reservado para karts controlados pela IA.
