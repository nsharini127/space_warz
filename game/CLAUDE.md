# Samurai Game - Instrucoes do Projeto

## O Projeto
Space shooter vertical (shmup) em Godot 4 / GDScript. Viewport 320x480. Partidas de 5 minutos com dificuldade escalavel, 9 armas com evolucoes, 8+ tipos de inimigos, sistema de drops e buffs.

## Regra #1: context.md
O arquivo `context.md` na raiz e a FONTE DE VERDADE do projeto. Leia antes de qualquer acao. Atualize ao final de qualquer mudanca.

## Regras Tecnicas Criticas
- **NUNCA** use sprite sheets como textura direta (sao multi-frame). Use `_draw()` procedural ou imagens single-frame (laser_*.png)
- **SEMPRE** leia um arquivo antes de editar
- Collision layers: Player=1, Enemy=2, PlayerBullet=4, EnemyBullet=8
- Viewport fixo: 320x480
- Signals para comunicacao entre nodes
- Grupos: "game", "enemy_hitbox", "enemy_body", "player_bullet"
- `is_instance_valid()` antes de acessar nodes que podem morrer
- Todo sistema deve ser resetavel para restart

## Equipe de Agentes

### Comandos Individuais
| Comando | Agente | Papel |
|---------|--------|-------|
| `/dev-gameplay` | Kenji | Gameplay, combate, IA, armas |
| `/dev-ui` | Yuki | HUD, menus, visual, shaders |
| `/dev-systems` | Ryu | Arquitetura, waves, state |
| `/designer-mechanics` | Akira | Balanceamento, economia |
| `/designer-level` | Sakura | Waves, pacing, level design |
| `/qa` | Hiro | Testes, bugs, validacao |
| `/pm` | Takeshi | PO/PM, priorizacao |
| `/writer` | Ren | Textos, narrativa, ideias |

### Comandos Orquestradores
| Comando | Funcao |
|---------|--------|
| `/team [tarefa]` | Orquestrador: analisa, delega e executa com os agentes certos |
| `/sprint [foco]` | Ciclo completo: PM planeja -> Devs implementam -> QA valida |
| `/backlog` | PM analisa projeto e gera backlog priorizado |
| `/ideate [tema]` | Brainstorm criativo com Writer + Designers |
| `/review [area]` | Auditoria completa de qualidade pelo QA |

## Objetivo de Longo Prazo
Transformar o jogo em qualidade AAA. Cada sprint deve deixar o jogo mensuravel e visivelmente melhor.
