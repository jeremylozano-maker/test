# Build Your Island RNG — décisions de design

## Règles validées
- 1 roll = 1 objet. Chaque bloc/arme/piège occupe 1 case. Rolls gratuits et infinis, inventaire en stacks.
- Grille 9 × 13 × 3 (hauteur max 3).
  - Blocs empilables. Une arme peut être au sol ou sur un bloc. Rien au-dessus d'une arme.
  - Pièges : au sol uniquement, rien au-dessus, les zombies ne les ciblent pas.
  - Gravité : si un bloc est détruit, tout ce qui est au-dessus descend d'un étage.
- Core : case (7,5) au centre. On ne construit pas sur sa case, mais on peut empiler au-dessus de lui.
  Il occupe 1 ou 2 étages selon sa hauteur (forçable avec l'attribut `GridLevels` sur workspace.Core).
- La hauteur de placement est automatique : l'objet va sur le haut de la colonne visée.
- Objets détruits pendant les vagues : ils restent détruits d'une vague à l'autre, la base est réparée seulement au STOP ou à la mort.
- Zombies : vont toujours vers l'objet (ciblable) le plus proche, sinon le Core.
- Mort : fenêtre de stats (zombies tués, coins gagnés, vagues survécues).
  - Revive (Robux) : Core et armes full vie, reprise à la vague de la mort.
  - Accepter : le joueur garde les coins, la base est restaurée, il ne perd rien.

## Raretés (base) — la Luck multiplie : poids = Chance × (1 + Luck × LuckFactor)
| Rareté | Chance | LuckFactor |
|---|---|---|
| Common | 60 % | 0 |
| Uncommon | 25 % | 0.5 |
| Rare | 10 % | 1 |
| Epic | 4 % | 1.5 |
| Legendary | 0.9 % | 2 |
| Mythic | 0.1 % | 2.5 |

Tier 1→5 d'une famille = Common → Legendary. Mythic : Thunder Tesla, War Mortar, Absolute Zero (+30 % stats).
Dans une rareté, poids : Block 6, Trap 3, Weapon 1 (les blocs sortent plus souvent).

## Skill Tree
| Compétence | Max | Coût niv. N→N+1 | Effet |
|---|---|---|---|
| Auto Roll | 1 | 300 | rolls automatiques |
| Luck | 10 | 100 × 1.6^N | +0.15 Luck / niveau |
| Roll Speed | 10 | 80 × 1.5^N | cooldown 2 s × 0.92^N (min 0.5 s) |
| Core HP | 10 | 120 × 1.55^N | +20 % vie du Core / niveau |

## Vagues
- Bouton START : le joueur lance la vague. Pas de construction pendant une vague. Vitesse x1 / x2 (x3 Robux plus tard).
- Zombies : 4 + 2 × vague, PV × 1.12^(vague-1). Fast dès la vague 3, Tank dès la 5, Tanks en plus toutes les 10.
- Ils apparaissent dans l'océan autour de l'île, vont vers le bas de la colonne la plus proche (blocs/armes), sinon le Core.
- Core : 500 PV × bonus Core HP.
- Coins par vague = 10 + 5 × vague, ×3 toutes les 10 vagues.
- Sauvegarde de la progression : uniquement le dernier checkpoint (1, 11, 21…). Mort, STOP ou déconnexion à la vague 34 → reprise à la 31.
- Mort : Accepter = reprise au checkpoint, coins gardés, base remise. Revive = même vague, tout au max (Robux, gratuit dans Studio pour tester).

## Phases
1. Configs + sauvegarde + Roll + Inventaire + Index ✅
2. Build / Delete sur le Damier (ghost, snap, ploc, empilement) ✅
3. Core + zombies + vagues + défenses + gravité + respawn fin de vague + écran de mort ✅
4. Coins + écran de mort + Skill Tree UI
5. Boss, ennemis, épée, effets, mobile, événements
