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
- Zombies : marchent vers le Core et attaquent l'objet (ciblable) le plus proche SUR LEUR CHEMIN (couloir d'une case entre eux et le Core), sinon le Core.
- Épée : le joueur frappe les zombies devant lui (8 studs, 0.5 s entre deux coups). Dégâts 15 × 1.25^niveau, amélioration avec les Coins (branche ⚔️ SWORD, 20 niveaux, 50 × 1.35^N).
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
Toutes les valeurs sont dans `ReplicatedStorage/Shared/SkillTreeConfig` (coûts, bonus, prérequis, positions, sons).
Niveaux sauvegardés dans `data.Skills[skillId]` (DataService). Achat validé par `SkillService.Purchase` (serveur).

| Branche | Compétence | Max | Prérequis | Effet réel |
|---|---|---|---|---|
| 🎲 Roll | Better Rolls | 10 | — | +3 %/niv de chance d'un 2e objet par roll (RollService) |
| 🎲 Roll | Auto Roll | 1 | Better Rolls 2 | bouton AUTO du Roll |
| 🎲 Roll | Roll Mastery | 5 | Better Rolls 3 | Rare+ garanti tous les 60 − 5×niv rolls |
| 🎲 Roll | Offline Rolls | 5 | Auto Roll 1 | 🚧 BIENTÔT (non achetable, niveau prêt à être sauvegardé) |
| 🍀 Luck | Luck | 10 | — | +0.15 Luck/niv (poids des raretés dans RollMath) |
| 🍀 Luck | Mythic Hunter | 5 | Luck 5 | +20 %/niv sur Legendary et Mythic |
| ⚡ Roll Speed | Roll Speed | 10 | — | cooldown serveur 2 s × 0.92^niv (min 0.5 s) |
| ⚡ Roll Speed | Quick Reveal | 3 | Roll Speed 3 | animation de roll −20 %/niv (visuel) |
| 🏝️ Island | Core HP | 10 | — | +20 %/niv de vie du Core (WaveService) |
| 🏝️ Island | Build Capacity | 10 | Core HP 1 | 60 objets posés + 10/niv (IslandService) |
| 🏝️ Island | Build Height | 2 | Build Capacity 3 | 3 étages + 1/niv (Grid:GetPlacement) |
| 🏝️ Island | Island Size | 3 | Core HP 5 | 🚧 BIENTÔT (demande d'agrandir le Damier) |
| ⚔️ (hors arbre) | Sword | 20 | — | dégâts de l'épée 15 × 1.25^niv (bouton SWORD) |

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
