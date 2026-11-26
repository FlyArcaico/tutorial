# Slime Rebirth — Hoja de ruta

Estado del proyecto por fases. Se actualiza al terminar cada fase.

## Orden de fases

| Fase | Contenido | Estado |
|---|---|---|
| A | Slime: modelo nuevo y animaciones propias | ✅ Hecha |
| B | R15, animaciones por raza, guardia, aterrizar, daño, muerte y reaparecer, caras del Slime | ✅ Hecha (pendiente de probar en Studio) |
| C | Habilidades y combate: Major Elf, Elf, Invocados, Ogre; impactos, cámara, recargas | ⏳ Siguiente |
| D | Pueblo más grande, tiendas como edificios, NPC con animación y diálogo, aviso de zona segura | ⏳ |
| E | Sonido, gráficos (cielo, luz) y rendimiento (StreamingEnabled, número de piezas) | ⏳ |
| F | Repaso general de errores con lo encontrado al probar | ⏳ |

## Fase A — Slime (hecha)

- [x] `shared/SlimeModel.luau`: diseño único del Slime, compartido por el juego y el menú.
- [x] `client/SlimeAnimator.luau`: el cuerpo entero se deforma (reposo, andar, correr, saltar,
      caer, aterrizar, atacar, daño, magia, morir).
- [x] El servidor avisa a todos al usar habilidades o absorber (`AttackFx`: "Cast" / "SlimeCast").
- [x] Autocomprobación en Studio: `server/Tests.luau` y `client/Tests.luau`.

## Fase B — Animaciones, muerte y Slime (hecha)

- [x] **Jugadores en R15** (antes R6): R6 no tiene codos ni rodillas, imprescindibles para
      una guardia y una forma de andar naturales. Adaptados la espada (RightHand), la capa
      del Invocado (UpperTorso), el fuego de las manos y la altura del Slime.
- [x] `client/AnimationData.luau` reescrito para R15 (15 articulaciones) con generadores:
      - Human: equilibrado, brazos separados del cuerpo, codos doblados, giro de hombros y cadera.
      - Elf / Major Elf: ligero, pasos altos.  Ogre: pesado, piernas abiertas, balanceo.
      - Invocados: elegantes con las manos listas; Fuego agresivo, Agua fluido.
      - Correr: inclinación, zancadas largas, codos a 90°, fase en el aire.
- [x] Guardia nueva: postura de combate de lado, pies separados, rodillas dobladas; con espada,
      la hoja en diagonal con la punta hacia el enemigo; sin espada, guardia de boxeo.
      El Ogre tiene la suya (más ancha y baja).
- [x] Aterrizar (tras caídas fuertes), recibir daño (retroceso) y morir (cae de espaldas y se
      queda tumbado).
- [x] Conservado el machaque del Ogre (pasado a R15).
- [x] **Muerte y reaparecer arreglados**:
      - Causa del fallo: el personaje se asignaba antes de meterlo en el mundo, y la
        preparación (`onCharacterAdded`) salía antes de conectar la reaparición.
      - Sin la "explosión" de Roblox (`BreakJointsOnDeath = false`); el cuerpo se queda quieto.
      - Pantalla "Has caído" con botón **Reaparecer**; el servidor comprueba que estés muerto.
- [x] Slime: silueta más suave y ovalada, base sin "anillo", y cara con 6 expresiones
      (`client/SlimeFace.luau`): normal, contento, enfadado, concentrado, triste, sorprendido.
      Cambian solas: atacar → enfadado, golpe → sorprendido, habilidad → concentrado,
      correr → contento, poca vida o muerto → triste.

## Fase B.2 — Refinado de la cara del Slime y detalles (hecha)

Probado por el dueño en Studio: andar, correr, morir y reaparecer funcionan bien.

- [x] Cara del Slime rehecha (`client/SlimeFace.luau`): sin cejas; cada ojo es UNA línea
      alargada y curvada (más gruesa en el centro), boca diminuta o ninguna.
      Expresiones: Normal, Energetic (correr), Happy `^^` (absorber), Angry (atacar, ojos
      inclinados hacia el centro), Focused (habilidad), Hurt `> <` (golpe), Sad (poca vida).
      Cambios con fundido suave.
- [x] Cara y mejillas siguen la curva del cuerpo (giran también hacia arriba/abajo) y van
      casi pegadas a la superficie. Mejillas más pequeñas y suaves.
- [x] Absorber y usar habilidades se distinguen (`SlimeAbsorb` / `SlimeCast`).
- [x] Guardia más compacta tipo boxeo (brazos cerca del cuerpo, codos doblados, manos a la
      altura del pecho), conservando el agarre de la espada; reacción al bloquear un golpe.
- [x] Reposo más vivo: cabeza que mira alrededor, cambio de peso entre piernas, pequeños
      ajustes de hombros y brazos. Andar y correr sin cambios.
- [x] Silenciado solo el sonido de muerte de Roblox.
- [x] Cuerpo del Slime, colores de las evoluciones (incluido el morado) y animaciones de
      movimiento sin cambios.

## Absorción del Slime (F) — secuencia nueva (hecha)

- [x] La esencia ya no desaparece al pulsar F: se reserva y la mueve el servidor siguiendo
      al slime (`Combat.animateEssence`), visible a través del cuerpo translúcido.
- [x] Éxito: acercarse (el slime se gira y camina hacia ella, se ensancha y brilla) →
      envolver (la parte de delante se estira y el cuerpo sube a su alrededor) → cerrar
      (la lleva al centro) → digerir (late, brilla, chispas cian y una onda suave).
- [x] Fallo: acercarse → forcejear (tiembla, no llega a cubrirla) → rebote hacia atrás
      gracioso; la esencia sale despedida y se desvanece; aviso "¡ABSORCIÓN FALLIDA!".
- [x] El resultado se decide en el servidor al empezar, con la probabilidad de siempre
      (`Config.AbsorbChance`). Los premios se dan al terminar la animación.
- [x] Conseguir la habilidad ya no es automático: tirada aparte
      (`Config.SkillAcquireChance`: base de cada habilidad + nivel + Devorador/Única
      + 10% por cada intento fallido). Aviso especial "《 Habilidad obtenida 》".
- [x] Durante la secuencia no se puede atacar, usar habilidades ni moverse (tras acercarse).
- Tiempos y probabilidades configurables en `Config.AbsorbSequence` y `Config.SkillAcquire`.

## Monstruos — Goblin de nivel 1 (hecho, pendiente de probar en Studio)

- [x] Murciélagos y lobos retirados de las tablas de aparición (sus datos, diseños,
      animaciones y misiones se conservan; las misiones se ocultan en el NPC).
- [x] Zonas con tablas de aparición reutilizables (`Config.Zones[].Spawns`: monstruo, peso,
      rango de niveles). El sitio de aparición se comprueba: fuera de la zona segura y sin
      árboles, rocas ni edificios encima.
- [x] Goblin (`Config.Monsters.Goblin`, diseño `Monsters.builders.GoblinTier1`):
      rig R15 completo, pequeño (~3,8 studs), cabeza grande, orejas puntiagudas, nariz ancha,
      ojos grandes con cejas preocupadas, colmillos, pelo despeinado, vendas, taparrabos,
      cinturón de cuero y garrote; tono de piel distinto en cada uno.
- [x] Animaciones (`AnimationData.Monster.Goblin`): reposo encorvado (mira a los lados, se
      rasca la cabeza), andar con pasos cortos y bamboleo, correr encorvado, garrotazo torpe
      (cargar, golpe, tropiezo), recibir daño y caer muerto.
- [x] IA: pasea cerca de donde apareció, persigue algo más lento que el jugador, se para
      al atacar y el golpe llega al bajar el garrote (se puede esquivar).
- [x] Misión nueva de nivel 1: "Goblins traviesos".
- Estructura preparada para variantes: cada goblin futuro es otra entrada con
  `Species = "Goblin"` y su propio `Builder` / `AnimSet`.
- Las habilidades del Slime que venían de murciélagos y lobos no se pueden conseguir
  mientras esos monstruos estén retirados. El Goblin no da habilidad (solo atributos).

## Goblin en Blender (hecho, pendiente de importar y probar en Studio)

Diseño aprobado por el dueño (vistas previas en `art/goblin/previews`).

- [x] Blender 5.3 instalado. `art/goblin/build_goblin.py` crea el modelo entero con código:
      `blender -b --factory-startup --python art/goblin/build_goblin.py -- art/goblin`
      Genera `goblin_v1.blend` (editable), `export/GoblinTier1.fbx`, la textura y
      `src/server/MonsterRigs/GoblinTier1.luau` (medidas para el juego).
- [x] 15 piezas R15 (cada una con su ropa, vendas o garrote), textura única de 1024 px con
      todos los colores horneados (también el iris), contorno anime incluido en la malla.
      Unos 32 000 triángulos en total (la cabeza, la pieza mayor, 12 000; límite de Roblox 20 000).
- [x] `server/MeshRig.luau`: monta cualquier monstruo de Blender. Averigua solo la escala y el
      giro con que se importó, comprueba que las piezas encajan y crea las articulaciones R15.
      Si el modelo no está o no encaja, se usa el Goblin de piezas (copia de seguridad).
- [x] Animaciones `GoblinMesh`: las mismas del Goblin sin la postura encorvada (ya está en el
      modelo).
- [ ] El dueño importa el FBX en Studio y lo guarda como `assets/models/GoblinTier1.rbxm`.
- [ ] Probar en Studio: tamaño, textura, contorno, animaciones, IA y muerte.
- Nota: brazos y piernas son piezas articuladas (se ve una pequeña unión en hombros, codos y
  rodillas). Para un cuerpo de una sola pieza que se deforme haría falta un rig con huesos
  (Bones); se puede estudiar más adelante.

## Fase 1 (monstruos) — IA, combate y física (hecha, pendiente de probar en Studio)

Copia de seguridad previa: etiqueta git `backup-antes-fase1`.

- [x] Física: grupos de colisión (`server/Physics.luau`). Jugadores y monstruos no se
      empujan entre sí (ni los monstruos entre ellos); todos chocan con el mundo.
- [x] El empujón de habilidades ya no lanza a los monstruos hacia arriba (solo horizontal,
      fuerza según su peso). Sin estados de sentarse, trepar, caer o ragdoll.
- [x] IA (Idle / Chase / Return) con datos en `Config.Monsters` + `Config.MonsterDefaults`:
      detección, se para a distancia de golpe, rodea, PathfindingService si hay obstáculos o
      se atasca, gira poco a poco, LeashRange, vuelta a casa con "Esquiva" y vida llena.
- [x] Golpe del monstruo: daño en el momento de la animación, solo si sigues cerca, delante
      y fuera de la zona segura; respeta el bloqueo; un golpe por ataque.
- [x] Golpe del jugador: destello y chispas en el monstruo; no se hace daño desde la zona
      segura.
- [x] Aparición por sitios fijos: un monstruo por sitio, RespawnTime configurable, no
      aparece encima de jugadores, monstruos ni objetos.
- [x] Recompensa para el jugador que más daño hizo (una sola vez).
- [x] Autocomprobación en vivo (muerte y reaparición) y guía `docs/PRUEBAS_MONSTRUOS.md`.
- [x] Probado por el dueño: física, recompensas, muerte y reaparición funcionan.
- [x] Ajuste: sin teletransportes al atacar (el giro ya no toca el CFrame: AlignOrientation),
      golpe comprobado en cada fotograma de la bajada del garrote (caja delante del goblin,
      sin paredes en medio), detección 40 / persecución 75 / correa 70 studs y memoria de
      aggro de quien le pega.
- [ ] Volver a probar en Studio: teletransporte, golpes de lado y detrás, persecución larga.

## Fase 2 — Fijar objetivo (hecho, pendiente de probar en Studio)

- [x] `client/TargetLock.luau`: rueda del ratón = seleccionar el más cercano / pasar al
      siguiente (60 studs); clic con la rueda = soltar; se suelta solo si muere, se aleja
      (90 studs) o mueres. El zoom pasa a las teclas I / O.
- [x] Cámara que encuadra al objetivo encima de la cámara normal (suave, sin meterse en
      paredes); al soltar, la cámara normal sigue desde donde estaba.
- [x] Panel arriba a la izquierda: retrato 3D (copia de la cabeza en un ViewportFrame, con
      movimiento suave), nombre y barra de vida sin números (verde / amarillo / rojo, rastro
      de daño, destello y sacudida al golpear). Contorno dorado sobre el enemigo fijado.
- [x] Quitadas las barras de vida flotantes (y su opción en Ajustes).
- Parpadeo del retrato: no es posible con el Goblin actual (los ojos están pintados en la
  textura). Se puede preparar en el Goblin Guerrero (ojos/párpados como piezas aparte).
- [ ] Goblin Guerrero (Blender): esperando las imágenes de referencia del dueño.

## Decisiones pendientes (preguntar al dueño)

- Invocados: el juego tiene **Fuego / Agua / Planta**; el documento de diseño habla de **Hielo**.
  De momento se mantiene Planta.
- Elf normal: ¿+3 de oro como el Major Elf? De momento solo el Major Elf.
- PvP: no existe; la zona segura protege de los monstruos (en el servidor).
- Imágenes de referencia de la cara del Slime: no llegaron a Claude (solo texto); la cara se
  ha hecho según la descripción escrita. Si se adjuntan, se ajusta a ellas.

## Recursos externos necesarios (no se inventan IDs)

- **Sonidos**: el juego no tiene ninguno. Se usarán los sonidos que trae Roblox y un
  archivo de IDs para que el dueño añada los suyos desde la Toolbox (Fase E).
- **Animaciones**: sistema propio de fotogramas clave, no necesita IDs.

## Problemas conocidos / a revisar en Studio

- Los ángulos de las animaciones se han calculado sin poder verlas: pueden necesitar ajustes.
- Orejas de Elf, gorro de Major Elf y cuernos de Ogre estaban colocados para la cabeza de R6:
  revisar que encajan en la cabeza R15.
- Pruebas fuera de Studio con Lune: no instalado (requiere permiso del dueño).
