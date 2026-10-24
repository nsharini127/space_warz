# Samurai Game - Contexto do Projeto

## Visao Geral
Space shooter vertical (shmup) feito em Godot 4 com GDScript. Viewport 320x480. O jogador controla uma nave, enfrenta waves de inimigos, coleta gems/XP, power-ups, e escolhe upgrades de armas entre waves.

## Estrutura do Projeto

```
samurai-game/
├── scripts/           (62 arquivos .gd)
│   ├── enemies/       enemy_base, enemy_runner, enemy_shooter, enemy_charger,
│   │                  enemy_midboss, enemy_tank, enemy_bomber, enemy_laser,
│   │                  meteor, mine, wave_spawner, boss_*
│   ├── items/         gem.gd, power_item.gd
│   ├── player/        player.gd
│   ├── projectiles/   bullet_player.gd, bullet_enemy.gd
│   ├── shared/        drop_table.gd, buff_system.gd
│   ├── systems/       environment_manager.gd, fever_system.gd, trophy_system.gd
│   ├── ui/            hud.gd, game_over.gd, pause_menu.gd, upgrade_menu.gd,
│   │                  boss_hp_bar.gd, main_menu.gd
│   ├── weapons/       weapon_manager.gd, weapon_registry.gd, orbital_weapon.gd,
│   │                  effects/drone_weapon.gd
│   └── game.gd        Controlador principal do jogo
├── scenes/            (22 arquivos .tscn)
│   ├── enemies/       Cenas de todos os inimigos
│   ├── items/         gem.tscn, power_item.tscn
│   ├── projectiles/   bullet_player.tscn, bullet_enemy.tscn
│   ├── ui/            Cenas de UI
│   └── game.tscn      Cena principal
├── assets/
│   ├── sprites/       Sprites de player, enemies, UI, projectiles
│   ├── audio/         Sons e musica
│   ├── backgrounds/   Fundos parallax
│   ├── tilesets/      Tilesets
│   └── ui/            Assets de interface
├── shaders/           Shaders (glow, flash, etc)
├── resources/         Recursos exportados
└── theme/             Temas de UI
```

## Arquitetura Principal

### game.gd (Controlador Central)
- Gerencia ciclo de jogo: start -> waves -> upgrade -> boss -> final boss -> victory/game over
- Timer de 5 minutos (`game_timer: float = 300.0`) com dificuldade escalavel
- `get_difficulty_multiplier()` retorna 1.0..2.0 baseado no tempo decorrido
- Pertence ao grupo "game" para inimigos consultarem dificuldade
- Flags: `boss_wave_active`, `pending_wave_complete`, `final_boss_spawned`, `game_won`
- Conecta signals de todos os subsistemas

### wave_spawner.gd
- Controla spawn de inimigos por wave com **burst spawning system**
- Enemies spawnam em bursts de 2-5 com 0.3s entre cada, pausas de 0.8-2.0s entre bursts
- `burst_size`: `clampi(2 + wave/4, 2, 5)` -- escala com wave
- `burst_pause`: `maxf(0.8, 2.0 - wave*0.08)` -- diminui com wave
- `_pick_enemy_type()`: Tank 10% (wave7+), Bomber 8% (wave8+), Laser 7% (wave10+)
- `_spawn_meteor_wave()`: Antes de boss waves (wave 4+), escalacao temporal (slow->fast->rapid)
- **Wave Flavor System**: `enum WaveFlavor { NORMAL, RUSH, SWARM, ELITE }`
  - Waves 1-2 e boss waves: sempre NORMAL
  - Waves 3+: NORMAL 40%, RUSH 25%, SWARM 20%, ELITE 15%
  - RUSH: burst_size = clampi(3+wave/3,3,6), burst_pause = 0.4s
  - SWARM: enemies +50%, burst_size=2, burst_pause=1.2s, 60% runners
  - ELITE: enemies *0.6 (min 4), burst_size=2, burst_pause=2.0s, no runners (shooters/chargers/tanks+)
  - `get_current_flavor_name()`: returns "" / "RUSH" / "SWARM" / "ELITE"
  - Flavor shown in wave announcement (e.g., "WAVE 5 - RUSH")
- **Formation spawning**: 4 formacoes predefinidas (v_shape, line, escort, pincer)
  - Cada formacao tem min_wave, offsets relativos, e tipo(s) de inimigo
  - Chance escala com wave: 10% base + 1.5% por wave
  - formation_cooldown (3-5 enemies) impede formacoes consecutivas
  - Nao spawna nos ultimos 5 inimigos (reserva para boss)
- Escala quantidade e velocidade de spawn pela dificuldade
- Boss/mecha boss waves mantém spawn_timer = 2.5s (pausa dramatica)

### weapon_manager.gd
- Gerencia ate 6 armas simultaneas
- Signal principal: `weapon_bullet_fired(bullet_scene, pos, dir, dmg, pierce, glow_color, weapon_id)`
- Armas projetil: front_laser, spread_shot, rear_cannon, side_cannons, homing_missile
- Armas efeito: lightning, shockwave, orbital_shield, drone
- Fire rate escala com `power_level` do player e `attack_speed_multiplier`

### weapon_registry.gd
- Definicoes puras de dados (const WEAPONS, const EVOLUTIONS)
- 9 armas base, cada uma com 5 niveis e 1 evolucao
- Campos: base_damage[], fire_interval[], projectile_count[], glow_color, etc.
- Helpers estaticos: get_damage_at_level(), get_fire_interval_at_level(), etc.

### Sistema de Sinais
```
weapon_manager.weapon_bullet_fired -> game._on_player_bullet_fired
wave_spawner.spawn_enemy -> game._on_spawn_enemy
enemy.enemy_killed -> game._on_enemy_killed
enemy.enemy_shoot -> game._on_enemy_shoot
player.player_died -> game._on_player_died
fever_system.fever_started -> game._on_fever_started
fever_system.fever_ended -> game._on_fever_ended
```

## Sistemas Implementados

### Drop System (drop_table.gd)
- `BASE_DROP_CHANCE = 0.15`
- Pesos: POWER:30, BOMB:18, HEALTH:10, ATTACK_SPEED:22, SHIELD:12, INVINCIBILITY:8
- Power overflow: quando power_level >= 8, coleta de POWER converte em +1 HP (se nao cheio)

### Fever System (fever_system.gd)
- 12 kills em janela de 2s ativa Fever Mode
- Fever dura 5s, cada kill durante fever estende +1s (max 8s)
- Durante fever: gems em dobro (get_gem_multiplier() retorna 2.0)
- Sinais: fever_started / fever_ended (flash dourado + screen shake)

### Buff System (buff_system.gd)
- Shield: 10s duracao
- Invincibility: 5s duracao
- Attack Speed: boost temporario

### Dificuldade
- Curva QUADRATICA: `1.0 + t*t*2.0` (t = tempo_decorrido / 300), range 1.0x -> 3.0x
- Inicio gentil (1.0x ate ~1.1x no primeiro minuto), acelerando nos ultimos 2 min
- Inimigos normais escalam HP e speed no _ready() via grupo "game"
- Boss e Midboss escalam via game.gd (GameConstants * difficulty_multiplier)
- Final boss: 150 HP base * difficulty (= 450 HP quando timer=0)
- Wave spawner escala: enemy count e spawn interval

### Items Visuais
- **power_item.gd**: Desenho procedural por tipo (raio, bomba, cruz, setas, hexagono, estrela)
- **gem.gd**: Cristais hexagonais rotativos, SMALL=8px verde, LARGE=12px dourado, efeito pulsante

### HUD
- Timer MM:SS top-center (amarelo -> laranja -> vermelho pulsante)
- Weapon panel: 44x34px por arma, procedural _draw() icons (weapon_icon_draw.gd), level dots, 4-char name abbreviation (60% opacity), borda dourada se evoluida, upgrade glow pulse (2s white flash via notify_weapon_upgrade)
- Score, wave, power level, hearts, graze counter
- Fever Mode indicator: centro-superior abaixo do timer
  - Combo inativo: hidden
  - Combo > 0 (sem fever): "COMBO x[N]" ciano 8px, opacidade = combo/12
  - Fever ativo: "FEVER!" dourado 14px pulsante (sin wave), glow laranja/vermelho atras, overlay vermelho sutil nas bordas
  - Metodos publicos: `show_fever()`, `hide_fever()`, `update_combo(count)`

## Inimigos

| Tipo | HP | Speed | Points | Wave Min | Comportamento |
|------|-----|-------|--------|----------|---------------|
| Runner | 1 | 100 | 10 | 1 | Desce reto |
| Shooter | 2 | 40 | 25 | 1 | Desce, para, atira |
| Charger | 3 | 60 | 50 | 3 | Desce, carrega no player |
| MidBoss | 15 | 20 | 100 | 5 | Mini-boss com patterns |
| Tank | 8 | 20 | 200 | 7 | Tanque pesado, ring de 6 bullets |
| Bomber | 5 | 60 | 150 | 8 | Cruza horizontal, dropa minas |
| Laser | 6 | 30 | 180 | 10 | Para, rastreia, beam por 1.5s |
| Meteor | 2-5 | 60-120 | 50 | Pre-boss | Cai reto, rotaciona, procedural draw |
| Mine | 2 | 30 | 25 | 8 | Dropada por Bomber, explode em ring |

## Armas

| ID | Nome | Tipo | Glow Color | Evolucao |
|----|------|------|------------|----------|
| front_laser | Front Laser | projectile | Ciano | Mega Laser |
| spread_shot | Spread Shot | projectile | Amarelo | Bullet Storm |
| homing_missile | Homing Missiles | projectile | Laranja | Swarm Rockets |
| rear_cannon | Rear Cannon | projectile | Vermelho | Dual Turret |
| side_cannons | Side Cannons | projectile | Verde | Cross Fire |
| lightning | Lightning | effect | Azul | Thunder Storm |
| orbital_shield | Orbital Shield | effect | Roxo | Plasma Ring |
| drone | Combat Drone | effect | Azul claro | Drone Swarm |
| shockwave | Shockwave | effect | Branco-azul | Nova Blast |

## Historico de Mudancas

### Sprint 3 - Fever Mode e Drop Rebalance

**Feature 1 - Fever Mode:**
- [x] Novo arquivo `scripts/systems/fever_system.gd`: combo tracking com janela de tempo, ativacao/desativacao de fever, extensao por kill
- [x] Integrado em game.gd: register_kill em _on_enemy_killed, gem multiplier em _drop_gems, sinais fever_started/fever_ended com flash e shake
- [x] Resetavel via fever_system.reset() em start_game()

**Feature 2 - Drop Rebalance:**
- [x] drop_table.gd: Pesos redistribuidos (POWER 45->30, BOMB 15->18, HEALTH 10->18, ATTACK_SPEED 17->18, SHIELD 8->10, INVINCIBILITY 5->6)
  - Rebalance Sprint 10: HEALTH 18->10, ATTACK_SPEED 18->22, SHIELD 10->12, INVINCIBILITY 6->8
- [x] player.gd: Power overflow - quando power_level >= 8, coleta de POWER converte em +1 HP se nao cheio
- [x] game.gd: _on_power_item_collected agora atualiza HUD de HP (para refletir overflow heal)

### Sessao 1 - Implementacao do Plano (8 itens)

**Fase 1 - Balance + Bug Fixes:**
- [x] Rebalanceamento de drops: BASE_DROP_CHANCE 0.25->0.15, pesos redistribuidos
- [x] Duracao de buffs: Shield 30s->10s, Invincibility 10s->5s
- [x] Fix boss death bug: flag `boss_wave_active` impede upgrade menu durante boss

**Fase 2 - Timer + Dificuldade:**
- [x] Timer 5 minutos com countdown no HUD (MM:SS, cores mudam com urgencia)
- [x] `get_difficulty_multiplier()` 1.0->2.0 baseado no tempo
- [x] Final boss ao timer=0 (100 HP fixo)
- [x] Tela de vitoria via `show_victory()`

**Fase 3 - Melhorias Visuais:**
- [x] Icons distintos para cada tipo de power-up (procedural _draw)
- [x] Gems hexagonais maiores com rotacao e glow
- [x] Weapon panel: 40x30, TextureRect icons, level dots, borda dourada

**Fase 4 - Variedade de Tiros:**
- [x] REVERTIDO - Bullet textures por arma causou bugs graves
  - Sprites de bullets sao sprite sheets (multi-frame), nao imagens unicas
  - Aplicar como texture renderizava a sheet inteira como imagem gigante
  - Sistema de glow_color via shader ja diferencia visualmente cada arma
  - Se revisitar: criar cenas de bullet dedicadas por arma com sprites calibrados

**Fase 5 - Novos Inimigos:**
- [x] Enemy Tank (wave 7+): Tanque pesado com ring de 6 bullets
- [x] Enemy Bomber (wave 8+): Cruza horizontal, dropa minas
- [x] Enemy Laser (wave 10+): Beam tracking com Line2D
- [x] Meteor (pre-boss): Procedural rock drawing, queda reta com rotacao
- [x] Mine: Explosiva, dropada por bomber, ring de 6 bullets ao explodir
- [x] wave_spawner integrado com todos os novos inimigos

### Sprint 2 - Balance, Dificuldade e Boss Experience

**Item 1 - Fix buff durations no player.gd (Bug P0):**
- [x] player.gd: apply_shield(30.0) -> apply_shield(10.0) (estava ignorando o nerf do buff_system)
- [x] player.gd: apply_invincibility(10.0) -> apply_invincibility(4.0)

**Item 2 - Curva de dificuldade quadratica + boss HP scaling:**
- [x] game.gd: `get_difficulty_multiplier()` agora usa curva quadratica: `1.0 + t*t*2.0`, range 1.0->3.0
- [x] game.gd: Boss HP agora aplica `* get_difficulty_multiplier()`
- [x] game.gd: Midboss HP agora aplica `* get_difficulty_multiplier()`
- [x] game.gd: Final boss HP: 150 * difficulty (era fixo 100)
- [x] constants.gd: Boss base HP: 25 + wave*5 (era 20 + wave*3), Midboss: 15 + wave*3 (era 12 + wave*2)

**Item 3 - Warning pre-boss dramatico:**
- [x] wave_announce.gd: Reescrito com 2 modos: wave normal (slide in/out ciano) e boss WARNING (overlay escuro, scan lines vermelhas, texto pulsante, linhas de perigo)
- [x] wave_spawner.gd: Boss waves tem spawn_timer = 2.5s (pausa dramatica antes do primeiro inimigo)
- [x] game.gd: Screen shake de 4.0 em boss wave announcements

**Item 4 - Fix boss morrendo durante upgrade:**
- [x] game.gd: _on_wave_completed() agora desabilita weapon_manager physics e limpa player bullets
- [x] game.gd: _on_upgrade_selected() reabilita weapon_manager physics
- [x] game.gd: start_game() garante weapon_manager physics ativo (fix QA P0-2)
- [x] game.gd: Nova funcao _clear_player_bullets() remove apenas bullets do player

**Bugs QA encontrados e corrigidos nesta sprint:**
5. **weapon_manager physics nao restaurado no restart**: Se jogador morresse durante upgrade menu, weapon_manager ficava desabilitado permanentemente -> adicionado set_physics_process(true) em start_game()
6. **Midboss HP sem difficulty multiplier no game.gd**: Era inconsistente com boss (que aplicava) -> adicionado multiplier

### Bugs Encontrados e Corrigidos (Historico)
1. **Bullet textures desproporcionais**: Sprite sheets usadas como textura unica -> revertido completamente
2. **Meteor parecia nave girando**: Usava enemy_base.png (sprite de nave) -> reescrito com _draw() procedural
3. **Variable shadowing em game.gd**: `sprite` declarado duas vezes -> renomeado, depois revertido junto com feature
4. **Homing missile cone amarelo gigante**: `bullet_rocket.png` e sprite sheet de 3 frames, renderizava inteira -> substituido por _draw() procedural (corpo laranja-amarelo com nose, fins e exhaust flame animado)

## Notas Tecnicas

### Convencoes do Projeto
- Desenho procedural via `_draw()` + `queue_redraw()` para items, gems, meteors, homing missiles
- Comunicacao entre nos via signals
- Dificuldade consultada via grupo "game": `get_tree().get_nodes_in_group("game")`
- Inimigos usam `enemy_hitbox` e `enemy_body` groups para deteccao
- Bullets usam procedural `_draw()` por weapon_id para visual distinto (front_laser=cyan beam, spread_shot=yellow pellet, rear_cannon=red bolt, side_cannons=green dash, drone=blue bolt)
- Fallback: shader `glow_color` para bullets sem weapon_id (enemy bullets)
- Collision layers: Player=1, Enemy=2, PlayerBullet=4, EnemyBullet=8

### Licoes Aprendidas
- Assets de bullet na pasta `assets/sprites/projectiles/` sao sprite sheets, NAO imagens unicas
- Trocar texturas em runtime em cena compartilhada causa problemas de escala/proporcao
- Procedural drawing e mais confiavel que sprites para objetos simples (meteors, items, bullets)
- weapon_id passado via signal permite procedural _draw() por arma sem cenas separadas

## Equipe de Agentes (Sistema Scrum Autonomo)

### Agentes Individuais
| Comando | Nome | Cargo | Faz o que |
|---------|------|-------|-----------|
| `/dev-gameplay` | Kenji | Gameplay Programmer | Mecanicas, combate, IA inimigos, armas |
| `/dev-ui` | Yuki | UI/Frontend Dev | HUD, menus, feedback visual, shaders |
| `/dev-systems` | Ryu | Systems Programmer | Arquitetura, waves, state, save/load |
| `/designer-mechanics` | Akira | Game Designer Mechanics | Balanceamento, economia, progressao |
| `/designer-level` | Sakura | Game Designer Level | Waves, pacing, composicao de fases |
| `/qa` | Hiro | QA Engineer | Testes, bugs, validacao, regressao |
| `/pm` | Takeshi | PO / PM | Priorizacao, roadmap, coordenacao |
| `/writer` | Ren | Roteirista | Textos, nomes, narrativa, worldbuilding |

### Comandos Orquestradores
| Comando | Funcao |
|---------|--------|
| `/team [tarefa]` | Orquestrador: analisa, delega e executa com os agentes certos |
| `/sprint [foco]` | Ciclo completo: PM planeja -> Devs implementam -> QA valida |
| `/backlog` | PM analisa projeto e gera backlog priorizado com roadmap AAA |
| `/ideate [tema]` | Brainstorm criativo: Writer + Designers geram ideias em paralelo |
| `/review [area]` | Auditoria completa de qualidade pelo QA (4 auditorias paralelas) |

### Como Usar
- **Individual**: `/dev-gameplay melhore a IA do enemy_laser`
- **Orquestrador**: `/team adicione sistema de particulas de explosao`
- **Sprint completa**: `/sprint foco em polish visual`
- **Brainstorm**: `/ideate novos modos de jogo`
- **Auditoria**: `/review sistema de armas`
- Cada agente le o context.md antes de atuar e atualiza ao final
- Devs implementam codigo, designers produzem specs, QA valida, PM coordena

### Sprint 3.5 - Fever Mode HUD Indicator (Yuki)

**Fever Mode visual no hud.gd:**
- [x] Variaveis: fever_active, fever_timer, combo_count, fever_label, fever_glow_label, fever_overlay
- [x] `_create_fever_indicator()`: Cria 3 elementos dinamicos (glow label, main label, screen overlay)
- [x] `_process(delta)`: Anima pulso do FEVER! (sin wave em escala/opacidade), combo counter, e overlay
- [x] Combo inativo: "COMBO x[N]" ciano 8px, opacidade proporcional a combo/12
- [x] Fever ativo: "FEVER!" dourado 14px pulsante, glow laranja/vermelho, overlay vermelho sutil
- [x] Metodos publicos: `show_fever()`, `hide_fever()`, `update_combo(count)`
- [x] Posicao: centro-superior, offset_top = MARGIN + 28 (abaixo do timer)
- [x] Nenhum elemento existente do HUD foi alterado

### Sprint 3 - Burst Spawning System (Ryu)

**Burst Spawning no wave_spawner.gd:**
- [x] Novas variaveis: burst_size, burst_spawn_interval (0.3s), burst_pause, enemies_in_current_burst, in_burst_pause, burst_pause_timer
- [x] start_wave(): burst_size escala com wave via `clampi(2 + wave/4, 2, 5)`, burst_pause via `maxf(0.8, 2.0 - wave*0.08)`
- [x] _process(): Spawn rapido (0.3s) dentro do burst, pausa entre bursts (0.8-2.0s)
- [x] Wave completion check mantido durante burst pause
- [x] Boss/mecha boss spawn_timer = 2.5s preservado (pausa dramatica)
- [x] Logica de boss, midboss, mecha boss e meteor wave intacta
- [x] Todas novas variaveis resetadas em start_wave()

### Sprint 4 - Upgrade Menu Polish (Yuki)

**Upgrade Menu entry animations:**
- [x] Cards slide up + fade in with stagger delay (0.15s between each card, 0.25s slide, 0.2s fade)
- [x] Title "CHOOSE UPGRADE" fades in over 0.3s
- [x] All tweens use TWEEN_PAUSE_PROCESS to work during pause
- [x] Tween easing: TRANS_BACK for cards (bouncy), TRANS_CUBIC for title

**Better visual tags (NEW / EVOLVE / Level):**
- [x] Tags now wrapped in PanelContainer with styled StyleBoxFlat backgrounds
- [x] NEW tag: dark green bg, green border, font size 9
- [x] EVOLVE tag: dark gold bg, gold border, font size 10, star prefix "★ EVOLVE"
- [x] Level tags (Lv.X→Y): dark gray bg, subtle border, font size 9
- [x] All tags have 1px black outline for readability, 3px corner radius

**Card hover glow enhancement:**
- [x] Hover: background brightens (+0.06 RGB), card scales to 1.02x via tween
- [x] Exit: restores original bg color, scales back to 1.0x
- [x] Hover/exit tweens use TWEEN_PAUSE_PROCESS

### Sprint 5 - Enhanced Game Over Screen (Yuki)

**Game stats tracking (game.gd):**
- [x] New tracking vars: enemies_killed, bosses_defeated, max_combo, time_survived
- [x] All reset in start_game()
- [x] enemies_killed incremented in _on_enemy_killed
- [x] bosses_defeated incremented in _on_boss_died and _on_mecha_boss_defeated
- [x] max_combo updated from fever_system.get_combo() each kill
- [x] _build_extra_stats() helper builds dict with all stats
- [x] Extra stats passed to show_game_over and show_victory
- [x] show_weapon_build(weapon_manager) called after game over/victory

**Score Grade System (game_over.gd):**
- [x] _calculate_grade(score, wave): S/A/B/C/D based on score and wave thresholds
- [x] Grade displayed as large colored letter between title and score
- [x] S=Gold 24px, A=Green 22px, B=Cyan 20px, C=Gray 18px, D=DarkGray 18px
- [x] Outline color is darkened version of grade color

**Contextual Messages (game_over.gd):**
- [x] _get_contextual_message(wave, score): wave-based motivational messages
- [x] Victory special message: "The galaxy is safe... for now."
- [x] Displayed in 8px gray below the grade label

**Score Counting Animation (game_over.gd):**
- [x] _process() animates score counting up from 0 to target
- [x] Increment = target_score/60 per frame (~1 second total)
- [x] 0.3s delay before animation starts
- [x] Animation stops on restart/quit

**Weapon Build Showcase (game_over.gd):**
- [x] show_weapon_build(weapon_manager): horizontal row of weapon icons
- [x] "YOUR BUILD" header in small gray text
- [x] Uses same _create_weapon_icon style as hud.gd (40x30px, level dots, gold border if evolved)
- [x] Positioned above restart/quit buttons
- [x] Handles 0 weapons gracefully (no display)

### QA Sprint 4 - Bugs Encontrados e Corrigidos

**P0 Corrigido:**
- [x] Score animation falhava no 2o+ game over: `_cleanup_dynamic_groups()` usava queue_free (deferred), ScoreLabelGroup antigo era encontrado antes do novo. Fix: `remove_child()` + `queue_free()` para remover imediatamente da arvore.

**P1 Corrigidos:**
- [x] enemies_killed contava inimigos off-screen (0 pts): Fix: gate com `if points > 0`
- [x] _build_extra_stats() usava `if player` sem is_instance_valid: Fix: trocado para `is_instance_valid(player)`

### Sprint 10 - Enemy Attack Telegraphing (Kenji)

**Visual telegraph system for 3 enemy types:**
- [x] enemy_charger.gd: 0.5s "telegraph" state replaces old "pause" state before charge
  - Sprite flashes overbright red (Color(2, 0.3, 0.3)) during wind-up
  - `_draw()` renders red arrow (30px) pointing toward player direction
  - Arrow tracks player in real-time during telegraph phase
  - Charger is stationary during telegraph (velocity = Vector2.ZERO)
  - After 0.5s, charge executes in last tracked direction
- [x] enemy_laser.gd: 0.8s dashed line telegraph during existing "charging" state
  - `_draw()` renders dashed line (8px dash, 6px gap) toward player
  - Line tracks player continuously during charge phase
  - Pulsing alpha via sin wave (0.25 +/- 0.15, 8Hz) for visibility
  - Line2D hidden during telegraph (procedural _draw() used instead)
  - After 0.8s, actual beam fires via Line2D as before
- [x] enemy_bomber.gd: 0.3s warning before each mine drop
  - Sprite blinks overbright white (Color(2, 2, 2)) during telegraph
  - `_draw()` renders downward arrow + circle indicator below bomber
  - Movement slows to 30% speed during telegraph
  - Mine drops after telegraph completes (not before)
  - mine_timer triggers telegraph instead of immediate drop
- [x] All existing behavior preserved; telegraphs ADD delay before attacks
- [x] All use `is_telegraphing: bool` + `telegraph_timer: float` pattern
- [x] All use `queue_redraw()` for procedural _draw() updates
- [x] `is_instance_valid()` checks on player_ref in all telegraph tracking

## Backlog Priorizado

### P1 - Alto Impacto (proximas sprints)
- ~~Burst spawning: Organizar waves em bursts com pausas (ritmo tensao/alivio)~~ DONE
- ~~Fever Mode: Combo kills -> power fantasy temporaria (glow, 2x gems, 50% bullet size)~~ DONE
- ~~Trofeus de Run: Achievements mid-run com bonus instantaneo~~ DONE
- ~~Rebalancear drops: POWER 45->30, HEALTH 10->18, power overflow -> heal~~ DONE
- ~~Formacoes predefinidas: V de runners, shooter escoltado, charger flankers~~ DONE

### P2 - Polish AAA
- ~~Bullet variety: Procedural _draw() por weapon_id com shapes distintos~~ DONE
- Som/musica: Efeitos sonoros para armas, inimigos, power-ups
- ~~Particulas: Explosoes, trails, impactos~~ PARTIAL (explosions + hit flash done)
- Eventos dramaticos: Mini-narrativas scriptadas por wave
- Sinergias de armas: Fusao de 2 armas Lv5 em super-arma
- ~~Game Over stats + grade + weapon showcase~~ DONE
- ~~Upgrade menu animations + tags~~ DONE

### P3 - Futuro
- Death recap cinematico: Replay slow-mo dos ultimos 3s
- Mais bosses: Boss patterns variados
- Modos de jogo: Endless, Daily Challenge
- Meta-progressao: Unlocks persistentes entre runs

### Sprint 4 - Procedural Explosion Effects (Kenji)

**Explosion system overhaul (explosion.gd):**
- [x] Rewritten with `setup(color, size_mult)` for customizable color and size
- [x] Particle system: 8*size_mult particles with velocity, shrinking, alpha fade
- [x] Central white flash, colored core, expanding ring
- [x] Backward compatible: `_ready()` generates default particles if `setup()` not called

**Enemy kill explosions (game.gd):**
- [x] `_spawn_explosion(pos, color, is_boss)`: Creates procedural explosion via script
- [x] Color mapping by enemy value: light orange (weak), orange (100pts), deep orange (200pts+), red-orange (boss 1000pts+)
- [x] Boss explosions: 2.5x size multiplier (20 particles vs 8)
- [x] Screen shake: 0.5 for regular kills, 4.0 for boss kills (uses maxf to not override larger shakes)

**Enemy hit flash (enemy_base.gd):**
- [x] Overbright white flash: `sprite.modulate = Color(3, 3, 3)` on hit (0.05s duration)
- [x] Replaced old red blink (0.2s alternating) with instant white flash

### Sprint 6 - Enemy Formation Spawning (Ryu)

**Formation system in wave_spawner.gd:**
- [x] FORMATIONS const: 4 predefined formations (v_shape, line, escort, pincer)
- [x] v_shape: 5 runners in V pattern, min_wave 3
- [x] line: 4 base enemies in horizontal line, min_wave 2
- [x] escort: 1 shooter center + 2 runner flanks, min_wave 5 (uses enemy_types array)
- [x] pincer: 4 chargers in pincer pattern, min_wave 6
- [x] _should_spawn_formation(): 10% + 1.5%/wave chance, skips last 5 enemies
- [x] _spawn_formation(): picks valid formation, spawns all at once with clamped positions
- [x] _get_scene_for_type(): maps type strings to preloaded PackedScene
- [x] formation_cooldown: 3-5 enemies between formations, reset in start_wave()
- [x] All formation enemies count toward enemies_spawned and enemies_alive
- [x] Boss, midboss, mecha boss, meteor spawning logic untouched

### Sprint 7 - Mid-Run Trophy System (Kenji)

**Trophy system (trophy_system.gd - NEW):**
- [x] 8 trophies: first_blood, combo_king, survivor, boss_slayer, arsenal, fever_master, graze_ace, untouchable
- [x] Each trophy grants instant bonus: score, heal, or damage
- [x] Signal `trophy_unlocked(id, name, bonus_text)` emitted on unlock
- [x] Time-based tracking: no_damage_timer for "Survivor" (2min no damage)
- [x] Wave-based tracking: took_damage_this_wave for "Untouchable"
- [x] Fever count tracking for "Fever Master" (3 fever activations)
- [x] Fully resetable via reset() for restart

**Trophy popup (trophy_popup.gd - NEW):**
- [x] Procedural _draw(): golden star icon, trophy name, bonus text
- [x] Background pill, floats upward, fades out over 2.5s
- [x] Self-cleaning via queue_free()

**Integration in game.gd:**
- [x] trophy_system initialized in _init_systems(), reset in start_game()
- [x] Hooks: on_enemy_killed, on_combo_update, on_player_hit, on_boss_defeated
- [x] Hooks: on_fever_started, on_weapon_count_changed, on_graze_update, on_wave_completed
- [x] update() called every frame in _process (check_time_trophies merged into update)
- [x] _on_trophy_unlocked: applies bonus (score/heal/damage) + spawns popup at top center
- [x] Trophy count included in _build_extra_stats() for game over screen

### QA Sprint 5 - Bugs Encontrados e Corrigidos (Hiro)

**P0 Corrigidos:**
- [x] Bullet trails (Line2D) not cleaned on restart: Trails added as direct children of game node were never freed in _on_restart(). Fix: added cleanup loop in _on_restart() that frees all transient effect nodes (trails, trophy popups, explosions, score popups, boss explosions, wave announcements).
- [x] Trophy popups not cleaned on restart: Same issue as trails -- popups added via add_child(popup) persisted across restarts. Fixed in same cleanup loop.
- [x] Missing is_instance_valid in _clear_player_bullets(): Iterating bullet_container children without validity check could error if bullet was queue_free'd. Fix: added is_instance_valid guard.
- [x] Missing is_instance_valid in _bullet_cancel(): Same issue as above. Fix: added is_instance_valid guard.

**P1 Corrigidos:**
- [x] check_time_trophies() called redundantly every frame: Was called separately from update() in game.gd _process. Merged into trophy_system.update() to reduce per-frame overhead.
- [x] Defensive check for player.damage in trophy bonus: Added "damage" in player check before applying damage bonus from arsenal trophy.

**P1 Noted (not fixed, low risk):**
- Formation enemies spawn all on same frame (4-5 enemies): Could cause minor frame spike on low-end devices. Consider staggering with create_timer like meteor_wave does.

### Procedural Weapon Icons (Yuki)

**New file: scripts/ui/weapon_icon_draw.gd:**
- [x] Extends Control, draws unique 16x16 procedural icon per weapon_id via `_draw()`
- [x] `setup(id, color, is_evolved)`: configures weapon_id, icon_color, evolved state
- [x] 9 unique designs: front_laser (3 vertical beams), spread_shot (fan pattern), homing_missile (rocket shape), rear_cannon (downward arrow), side_cannons (dual horizontal arrows), lightning (zigzag bolt), orbital_shield (ring with orbiting dots), drone (diamond with propellers), shockwave (concentric arcs)
- [x] Evolved weapons render in gold (1.0, 0.85, 0.2), normal in weapon glow_color

**hud.gd _create_weapon_icon() updated:**
- [x] Replaced TextureRect icon + text fallback with procedural weapon_icon_draw.gd Control
- [x] Eliminated dependency on generic icon_*.png files (icon_attack, icon_fireball, icon_multishot, icon_defense)
- [x] Each weapon now visually distinct in the HUD panel

### Weapon Panel Enhancement (Yuki)

**Upgrade glow pulse (hud.gd):**
- [x] `_recently_upgraded: Dictionary` tracks weapon_id -> remaining time (2.0s)
- [x] `notify_weapon_upgrade(weapon_id)`: sets 2s glow timer for weapon
- [x] `_process()`: ticks down timers, applies pulsing modulate Color(1+pulse*0.5, 1+pulse*0.3, 1+pulse*0.3) where pulse fades 1.0->0.0
- [x] Resets modulate to Color.WHITE when timer expires
- [x] Each icon container stores weapon_id via set_meta("weapon_id", id)

**Weapon name abbreviation (hud.gd):**
- [x] Tiny label (font_size 4) below level dots showing first 4 chars of display_name in uppercase
- [x] Color: weapon glow_color at 60% opacity, outline at 40% opacity
- [x] Examples: "FRON", "SPRE", "HOMI", "REAR", "SIDE", "LIGH", "ORBI", "COMB", "SHOC"

**Panel size increase:**
- [x] custom_minimum_size from 40x30 to 44x34
- [x] weapon_panel offset_top from -38 to -42 to accommodate taller panels

**game.gd integration:**
- [x] _on_weapon_added(): calls hud.notify_weapon_upgrade(weapon_id)
- [x] _on_weapon_leveled_up(): calls hud.notify_weapon_upgrade(weapon_id)

**game_over.gd _create_weapon_icon() updated:**
- [x] Same replacement: TextureRect -> procedural weapon_icon_draw.gd
- [x] Weapon build showcase on game over screen now uses unique icons

### Sprint 8 - Procedural Bullet Visuals (Kenji)

**Distinct bullet shapes per weapon (bullet.gd):**
- [x] New `weapon_id` property: when set, hides Sprite2D and GlowBack, uses `_draw()` instead
- [x] `_draw_timer` incremented each frame for pulse animation, `queue_redraw()` every physics frame
- [x] front_laser: Elongated cyan laser beam (3px wide, 14px tall) with bright center line and tip glow
- [x] spread_shot: Yellow round pellet (3px radius) with bright center dot and soft outer glow
- [x] rear_cannon: Thick red energy bolt (5px wide, 10px tall) with dark edges and hot white core
- [x] side_cannons: Thin green laser dash (2px wide, 10px tall) with sharp bright center and tip point
- [x] drone: Small blue-white bolt for drone bullets
- [x] All shapes have animated pulse effect (sin wave on alpha/glow intensity)

**Signal update (weapon_manager.gd):**
- [x] `weapon_bullet_fired` signal now includes `weapon_id: String` as 7th parameter
- [x] `_current_weapon_id` set in `_fire_weapon()` before match block
- [x] `_emit_bullet()` passes `_current_weapon_id` in signal emission
- [x] `_on_drone_shoot()` passes `"drone"` as weapon_id

**game.gd integration:**
- [x] `_on_player_bullet_fired()` accepts `weapon_id: String = ""` (backward compatible)
- [x] Sets `bullet.weapon_id` before add_child so _ready() can hide sprites
- [x] Shader glow_color application skipped when weapon_id is set (procedural draw handles visuals)

**Not touched:** homing_missile (already has dedicated homing_bullet.gd with its own procedural draw)

### QA Sprint 6 - Bugs Encontrados e Corrigidos (Hiro)

**P0 Corrigidos:**
- [x] `_recently_upgraded` dict not cleared on restart (hud.gd): Stale upgrade glow timers accumulated across restarts, causing unnecessary _process iteration and potential visual artifacts. Fix: added `_recently_upgraded.clear()` in `update_weapons()`.
- [x] Fever HUD state not reset on restart (game.gd): If player died during Fever Mode, "FEVER!" indicator and red border overlay persisted into the next game. Fix: added `hud.hide_fever()` in `start_game()`.

**P0 Verified Clean:**
- [x] Signal signature `weapon_bullet_fired` (7 params): All emitters and receivers match. `_on_player_bullet_fired` uses defaults for backward compatibility. `_on_drone_shoot` correctly passes all 7 params.
- [x] No agent conflicts in game.gd: `_on_player_bullet_fired`, `_on_weapon_added`, `_on_weapon_leveled_up` all integrate cleanly with bullet variety, weapon icons, and upgrade glow features.
- [x] No agent conflicts in hud.gd: Fever system, weapon panel, and upgrade glow coexist cleanly in `_process()`. No duplicate functions or overwritten code.
- [x] `weapon_id` set before `add_child` in game.gd: Ensures `_ready()` can hide sprite nodes for procedural draw.
- [x] `is_instance_valid` checks present in all necessary locations.

**P1 Noted (not fixed, low risk):**
- `queue_redraw()` called every physics frame per weapon bullet (bullet.gd): Acceptable given short bullet lifetimes, but could matter with extreme bullet counts.
- game_over.gd weapon icon size (40x30) differs from hud.gd (44x34): Intentional, different UI contexts.

### Sprint 9 - Audio Bus Layout & Music Crossfade System (Ryu)

**Audio Bus Layout (default_bus_layout.tres - NEW):**
- [x] 3 buses: Master (index 0), Music (index 1), SFX (index 2)
- [x] Music and SFX both send to Master at 0dB
- [x] Godot 4 AudioBusLayout .tres format

**game.tscn bus assignments:**
- [x] BGMusic: bus = &"Music"
- [x] BGMusicAlt: bus = &"Music" (NEW node for crossfade)
- [x] All SFX nodes (SFXShoot, SFXHit, SFXEnemyDie, SFXPowerup, SFXGameOver, SFXLevelUp): bus = &"SFX"

**Music crossfade system (game.gd):**
- [x] `@onready var bg_music_alt` for second music player
- [x] `_crossfade_music(track)`: Loads track into inactive player, fades from -40dB to 0dB over 1.5s while fading old player out
- [x] `_process_music_fade(delta)`: Linear interpolation of volume_db each frame, stops old player when complete
- [x] `_set_music_pitch(pitch)`: Sets pitch_scale on both music players simultaneously
- [x] Music resources loaded in `_ready()`: `music_fight` and `music_adventure`
- [x] `start_game()`: Full music reset (stop both players, reset pitch/volume/fade state), then crossfade to theme_fight.ogg
- [x] `_on_player_died()`: Crossfade to theme_adventure.ogg (replaces hard stop)
- [x] `_on_boss_died()` (final boss victory): Crossfade to theme_adventure.ogg (replaces hard stop)
- [x] Boss spawn (`_on_spawn_enemy` is_boss, `_on_spawn_mecha_boss`, `_spawn_final_boss`): pitch_scale = 1.1 for intensity
- [x] Boss death (`_on_boss_died`, `_on_mecha_boss_defeated`): pitch_scale reset to 1.0
- [x] All music state fully resetable for restart

### Sprint 9 - Context-Specific SFX & Polyphony (Kenji)

**New AudioStreamPlayer nodes (game.tscn):**
- [x] SFXExplosion: bus = &"SFX" - for boss/tough enemy kills (explosion.wav)
- [x] SFXCoin: bus = &"SFX" - for gem collection (coin.wav, -6dB)
- [x] SFXAccept: bus = &"SFX" - for upgrade selection (accept.wav)
- [x] SFXBomb: bus = &"SFX" - for bomb activation (sword.wav)

**Context-specific sound assignments (game.gd):**
- [x] Enemy killed: explosion.wav for 200+ point enemies (tank, laser, bomber, boss), slash sounds for regular enemies
- [x] Gem collected: coin.wav with slight pitch variation (0.95-1.05)
- [x] Upgrade selected: accept.wav replaces powerup.wav in _on_upgrade_selected
- [x] Bomb activated: sword.wav plays on _on_bomb_activated
- [x] Boss wave warning: sfx_hit with pitch_scale 0.6 for deep warning boom
- [x] Pickups (power/bomb/health/buff): keep powerup.wav

**Polyphony (game.gd _ready):**
- [x] sfx_shoot.max_polyphony = 4 (rapid-fire weapons no longer cut off)
- [x] sfx_enemy_die.max_polyphony = 3
- [x] sfx_coin.max_polyphony = 4 (many gems collected at once)
- [x] sfx_explosion.max_polyphony = 2
- [x] sfx_hit.max_polyphony = 2

**Pitch variation for organic feel (game.gd):**
- [x] Shooting: sfx_shoot.pitch_scale = randf_range(0.9, 1.1) per shot
- [x] Enemy die: sfx_enemy_die/sfx_explosion.pitch_scale = randf_range(0.85, 1.15)
- [x] Coin: sfx_coin.pitch_scale = randf_range(0.95, 1.05)

**Audio assets now in use:**
- explosion.wav: boss/tough enemy kills (was UNUSED)
- coin.wav: gem collection (was UNUSED)
- accept.wav: upgrade selection (was UNUSED)
- sword.wav: bomb activation (was UNUSED)

### Sprint 10 - Balance Pass (Kenji)

**Spread Shot buff (weapon_registry.gd):**
- [x] base_damage [1,1,2,2,3] -> [2,2,3,3,4]: Brings DPS closer to Front Laser without exceeding it

**Drop weight rebalance (drop_table.gd):**
- [x] HEALTH 18->10 (power overflow already heals), ATTACK_SPEED 18->22 (more impactful for DPS)
- [x] SHIELD 10->12, INVINCIBILITY 6->8 (slightly more common defensive drops)

**Formation chance reduction (wave_spawner.gd):**
- [x] _should_spawn_formation() formula: 0.15 + wave*0.03 -> 0.10 + wave*0.015
- [x] Wave 10 formation chance: 45% -> 25% (reduces formation spam)

**Charger points fix (enemy_charger.gd + .tscn):**
- [x] points 250 -> 50: Was incorrectly set at 250 (should be between runner 10pts and shooter 25pts, but harder to dodge)

### Sprint 11 - Wave Flavor Variety System (Ryu)

**Wave Flavor system (wave_spawner.gd):**
- [x] New enum `WaveFlavor { NORMAL, RUSH, SWARM, ELITE }` and `current_flavor` variable
- [x] `_select_wave_flavor()`: Waves 1-2 and boss waves always NORMAL; waves 3+ weighted random (NORMAL 40%, RUSH 25%, SWARM 20%, ELITE 15%)
- [x] RUSH flavor: burst_size = clampi(3+wave/3,3,6), burst_pause = 0.4s (aggressive fast bursts)
- [x] SWARM flavor: enemies_to_spawn * 1.5, burst_size=2, burst_pause=1.2s, `_pick_enemy_type_swarm()` (60% runners, 25% base, 15% shooters)
- [x] ELITE flavor: enemies_to_spawn * 0.6 (min 4), burst_size=2, burst_pause=2.0s, `_pick_enemy_type_elite()` (no runners, picks from shooters/chargers/tanks/bomber/laser based on wave)
- [x] `get_current_flavor_name()` returns "" for NORMAL, "RUSH"/"SWARM"/"ELITE" otherwise
- [x] Flavor selected fresh each wave in start_wave(), `current_flavor` init to NORMAL

**Meteor wave escalation (wave_spawner.gd):**
- [x] `_spawn_meteor_wave()` now uses tiered timing: first 40% at 0.5s (slow), next 40% at 0.25s (fast), last 20% at 0.15s (rapid)
- [x] Creates escalating tension before boss instead of uniform 0.3s intervals

**Wave announcement flavor display (game.gd):**
- [x] `_show_wave_announce()` now appends flavor name to label (e.g., "WAVE 5 - RUSH")
- [x] Uses `wave_spawner.get_current_flavor_name()`, only appends if non-empty
- [x] Boss waves and NORMAL waves show plain label (no suffix)

### Sprint 12 - UI Polish Pass (Yuki)

**trophy_popup.gd:**
- [x] Hardcoded colors replaced with UIColors.TROPHY_NAME, TROPHY_BONUS, PANEL_BG
- [x] Font sizes: 10→UIColors.FONT_BODY, 8→UIColors.FONT_SMALL

**wave_announce.gd:**
- [x] Wave label font_size 11→UIColors.FONT_HEADING (12)
- [x] Boss WARNING font_size 16→UIColors.FONT_TITLE
- [x] All hardcoded colors replaced: cyan text→UIColors.CYAN, red warning→UIColors.BOSS_WARNING, outline→UIColors.OUTLINE_BLACK, red lines→UIColors.RED
- [x] Accent line colors derived from UIColors.CYAN

**boss_hp_bar.gd:**
- [x] Boss name font_size 8→UIColors.FONT_SMALL
- [x] WARNING label font_size 7→UIColors.FONT_TINY

**game_over.gd:**
- [x] Added `_is_animating` guard to `_on_restart()` and `_on_quit()` to prevent double-trigger
- [x] `_is_animating` reset in `show_game_over()` and `show_victory()`
- [x] Grade font sizes now derived from UIColors.FONT_TITLE (+ offset per grade)
- [x] Game over title font_size 18→UIColors.FONT_TITLE + 2
- [x] Quit button hover/pressed colors derived from UIColors.BTN_DANGER_BG/BORDER

**upgrade_menu.gd (previous sprint):**
- [x] Full rewrite with UIColors constants, keyboard focus chain, fade-out animation

**hud.gd (previous sprint):**
- [x] All 40+ hardcoded colors→UIColors, font sizes normalized to tiers

**pause_menu.gd (previous sprint):**
- [x] UIColors integration

### Bug Fix - Boss Dying During Upgrade Menu (P0)

**Root cause:** weapon_manager.gd uses `_process()` for all weapon firing, but game.gd was calling `set_physics_process(false)` which only stops `_physics_process()`. Weapons kept firing during upgrade menu.

**game.gd fixes:**
- [x] Changed all 3 `set_physics_process()` calls to `set_process()` for weapon_manager (start_game, _on_wave_completed, _on_upgrade_selected)
- [x] New `_clear_effect_weapons()`: removes active lightning/shockwave/flamethrower effect nodes
- [x] `_clear_effect_weapons()` called in `_on_wave_completed()` alongside `_clear_player_bullets()`

### Bug Fix - UI Layout Responsiveness (game_over.gd + upgrade_menu.gd)

**Root cause:** Dynamically created UI nodes used `SIZE_SHRINK_CENTER` inside VBoxContainers, causing them to collapse to minimum width. Additionally, upgrade cards manipulated `position.y` for animation, which breaks managed layout (layout_mode=2).

**game_over.gd fixes:**
- [x] All dynamic containers (grade, message, stat pairs, stats grid, weapon build) changed from `SIZE_SHRINK_CENTER` to `SIZE_EXPAND_FILL`
- [x] Stats rows changed to `SIZE_EXPAND_FILL` + `ALIGNMENT_CENTER` (centered content in full-width row)
- [x] Message label: removed `custom_minimum_size.x = 260`, uses `SIZE_EXPAND_FILL` to fill parent width naturally
- [x] Buttons remain `SIZE_SHRINK_CENTER` (intentionally centered with fixed min width)

**upgrade_menu.gd fixes:**
- [x] Cards changed from `SIZE_SHRINK_CENTER` to `SIZE_EXPAND_FILL` (fill VBoxContainer width)
- [x] Entry animation: removed `position.y += 30` / `position.y - 30` (breaks managed layout). Now fade-only via `modulate.a`
- [x] Hover effect: removed `scale` tween (breaks managed layout). Now color-only (bg + border change)
- [x] Click button overlay: uses `set_anchors_and_offsets_preset(PRESET_FULL_RECT)` instead of manual anchor assignment
- [x] Panel content margin: 12px -> 20px for better card spacing
- [x] Heal fallback: guarantees 3 upgrade choices when weapon/utility pool depleted
