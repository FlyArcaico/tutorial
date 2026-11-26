# Slime Rebirth — Hoja de ruta

Estado del proyecto por fases. Se actualiza al terminar cada fase.

## Orden de fases

| Fase | Contenido | Estado |
|---|---|---|
| A | Slime: modelo nuevo y animaciones propias | ✅ Hecha (pendiente de probar en Studio) |
| B | Animaciones humanoides por raza (Human, Elf, Major Elf, Ogre, Invocados) + recibir daño, morir, aterrizar | ⏳ Siguiente |
| C | Habilidades y combate: Major Elf, Elf, Invocados, Ogre; impactos, cámara, recargas | ⏳ |
| D | Pueblo más grande, tiendas como edificios, NPC con animación y diálogo, aviso de zona segura | ⏳ |
| E | Sonido, gráficos (cielo, luz) y rendimiento (StreamingEnabled, número de piezas) | ⏳ |
| F | Repaso general de errores con lo encontrado al probar | ⏳ |

## Fase A — Slime (hecha)

- [x] `shared/SlimeModel.luau`: diseño único del Slime, compartido por el juego y el menú.
  - Cuerpo translúcido (Glass) con base más ancha (forma "mochi"), luz interior,
    reflejo grande y puntito brillante, ojos de raya curvada por fuera del cuerpo,
    mejillas sonrosadas y contorno azul clarito (Highlight).
- [x] `client/SlimeAnimator.luau` reescrito: el cuerpo entero se deforma y todas las piezas lo siguen.
  - Reposo (respira), andar (saltitos), correr (saltos largos inclinado), saltar (se estira),
    caer, aterrizar (se aplasta y rebota), atacar (se estira hacia delante),
    recibir daño (tiembla y se pone rojo), magia/absorber (brilla por dentro y suelta chispas),
    morir (se derrite).
- [x] El servidor avisa a todos al usar habilidades o absorber (`AttackFx`: "Cast" / "SlimeCast").
- [x] Autocomprobación en Studio: `server/Tests.luau` y `client/Tests.luau` (resultado en Output).

## Decisiones pendientes (preguntar al dueño)

- Invocados: el juego tiene **Fuego / Agua / Planta**; el documento de diseño habla de **Hielo**.
  De momento se mantiene Planta.
- Elf normal: ¿+3 de oro como el Major Elf? De momento solo el Major Elf.
- PvP: no existe; la zona segura protege de los monstruos (en el servidor).

## Recursos externos necesarios (no se inventan IDs)

- **Sonidos**: el juego no tiene ninguno. Se usarán los sonidos que trae Roblox y un
  archivo de IDs para que el dueño añada los suyos desde la Toolbox (Fase E).
- **Animaciones**: se hacen con el sistema propio de fotogramas clave (`client/AnimationData.luau`),
  no necesitan IDs. Si en el futuro se quieren animaciones subidas a Roblox, se pueden enchufar.

## Problemas conocidos

- Todo se valida con Selene, StyLua, Rojo y la autocomprobación, pero **no se ha podido ver en
  Studio** desde aquí: los ángulos de las animaciones pueden necesitar ajustes al verlos.
- Pruebas fuera de Studio con Lune: no instalado (requiere permiso del dueño).
