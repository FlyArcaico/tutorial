# Pruebas de los monstruos (Goblin como referencia)

## Automáticas (salen solas en la ventana Salida al pulsar Jugar en Studio)

- `[Autocomprobación] ✓ Servidor`: configuración, grupos de colisión, valores de cada
  monstruo, quién se lleva la recompensa, modelo 3D.
- `[Autocomprobación en vivo] ✓ Monstruos` (unos 25 segundos después de empezar):
  - todos los monstruos aparecidos están en el grupo de colisión `Monsters`, los controla
    el servidor, están en el suelo, fuera de la zona segura y hay uno por sitio;
  - los jugadores están en el grupo `Players`;
  - mata a un goblin: muere una sola vez, se quita la barra de vida, el cuerpo no explota,
    desaparece y vuelve a aparecer en su sitio con la vida llena y tranquilo.

Si algo falla sale en amarillo con el motivo.

## Ver qué está haciendo un monstruo

En el Explorador: `Workspace > Monsters > Goblin`. En Propiedades, abajo del todo
(Atributos), `AIState` dice lo que hace: `Idle` (en su sitio), `Chase` (persigue),
`Return` (vuelve a su sitio) o `Dead`.

## Manuales con varios jugadores

En Studio: pestaña **Probar** → en "Clientes y servidores" elige **2 jugadores** → **Iniciar**.
Se abren 3 ventanas: el servidor y dos jugadores.

| # | Prueba | Qué debe pasar |
|---|---|---|
| 1 | Un jugador se acerca a un goblin | A unos 40 studs te ve (si no hay una pared en medio) y corre hacia ti sin saltos ni teletransportes. Se para a distancia de golpe y se gira hacia ti poco a poco. |
| 2 | Quedarse quieto delante | Levanta el garrote, lo baja y el daño llega al bajarlo. Espera ~1,7 s entre golpes. |
| 3 | Apartarse lejos justo cuando levanta el garrote | Falla el golpe (sin daño). |
| 3b | Moverse un poco de lado mientras ataca | Se gira hacia ti y normalmente te acierta. |
| 3c | Ponerse detrás de él mientras ataca | Intenta girarse; si llegas a su espalda antes de que baje el garrote, falla. |
| 4 | Bloquear (F) | El golpe gasta la barra de guardia en vez de vida. |
| 5 | Caminar contra el goblin, saltar encima, usar el Dash (Q) a través de él | Nadie sale volando ni se queda atascado: atraviesas al goblin. |
| 6 | Pegarle y huir | Te sigue aunque salgas de sus 40 studs de detección: te persigue mientras estés a menos de 75 studs (y te recuerda 5 s más). Si se aleja más de 70 studs de su sitio, se da la vuelta, vuelve corriendo, los golpes le hacen "Esquiva" y al llegar recupera la vida. |
| 7 | Entrar en la zona segura del pueblo | Deja de perseguirte y vuelve. No te puede golpear dentro. |
| 8 | Pegar desde dentro de la zona segura | Sale "Zona segura" y no hace daño. |
| 9 | Dos jugadores pegan al mismo goblin | Cada golpe resta vida una vez. La XP y el oro van **solo** para quien más daño le hizo. |
| 10 | Varios goblins contra dos jugadores | Se reparten y rodean en vez de amontonarse. Ninguno sale volando. |
| 11 | Matar un goblin | Animación de caída, sin explosión; la barra desaparece; desaparece a los ~2,6 s; reaparece en su sitio a los ~12 s. |
| 12 | Un jugador se va del juego en mitad de la pelea | El goblin vuelve a su sitio. Si el otro jugador lo mata, la recompensa es para él. |
| 13 | Habilidades con empujón (Puño de roca, Chillido sónico...) | El goblin se desplaza en horizontal, sin salir volando. |
| 14 | Goblin detrás de un árbol o una casa | Lo rodea para llegar a ti (camino de PathfindingService). |
