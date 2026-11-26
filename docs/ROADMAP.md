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

## Decisiones pendientes (preguntar al dueño)

- Invocados: el juego tiene **Fuego / Agua / Planta**; el documento de diseño habla de **Hielo**.
  De momento se mantiene Planta.
- Elf normal: ¿+3 de oro como el Major Elf? De momento solo el Major Elf.
- PvP: no existe; la zona segura protege de los monstruos (en el servidor).
- Imagen de referencia de las caras del Slime: no llegó; las expresiones son de estilo anime genérico.

## Recursos externos necesarios (no se inventan IDs)

- **Sonidos**: el juego no tiene ninguno. Se usarán los sonidos que trae Roblox y un
  archivo de IDs para que el dueño añada los suyos desde la Toolbox (Fase E).
- **Animaciones**: sistema propio de fotogramas clave, no necesita IDs.

## Problemas conocidos / a revisar en Studio

- Los ángulos de las animaciones se han calculado sin poder verlas: pueden necesitar ajustes.
- Orejas de Elf, gorro de Major Elf y cuernos de Ogre estaban colocados para la cabeza de R6:
  revisar que encajan en la cabeza R15.
- Pruebas fuera de Studio con Lune: no instalado (requiere permiso del dueño).
