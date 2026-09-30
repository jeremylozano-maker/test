# Lance les tests Luau du Skill Tree hors de Roblox Studio.
# Prérequis : l'exécutable `luau` (https://github.com/luau-lang/luau) dans le PATH ou via LUAU=/chemin/luau
# Utilisation : python3 tests/run_tests.py
import os, pathlib, subprocess, sys, tempfile

TESTS = pathlib.Path(__file__).parent
SRC = TESTS.parent / "src"
LUAU = os.environ.get("LUAU", "luau")

def module(name, rel):
    return f'Modules["{name}"] = function(script)\n{(SRC / rel).read_text()}\nend\n'

SHARED = "ReplicatedStorage/Shared/"
LOGIC = {
    "Items": SHARED + "Items.lua", "Rarities": SHARED + "Rarities.lua",
    "SkillTreeConfig": SHARED + "SkillTreeConfig.lua", "SkillTree": SHARED + "SkillTree.lua",
    "RollMath": SHARED + "RollMath.lua", "Grid": SHARED + "Grid.lua",
    "SkillService": "ServerScriptService/Services/SkillService.lua",
    "RollService": "ServerScriptService/Services/RollService.lua",
}
UI = {
    "Items": SHARED + "Items.lua", "Rarities": SHARED + "Rarities.lua",
    "SkillTreeConfig": SHARED + "SkillTreeConfig.lua", "SkillTree": SHARED + "SkillTree.lua",
    "UIKit": SHARED + "UIKit.lua", "HexUI": SHARED + "HexUI.lua", "HudState": SHARED + "HudState.lua",
    "SkillService": "ServerScriptService/Services/SkillService.lua",
    "SkillTreeClient": "StarterPlayerScripts/SkillTreeClient.client.lua",
}

def run(prelude, modules, test_file, extra=""):
    parts = [(TESTS / prelude).read_text(), extra] + [module(n, r) for n, r in modules.items()]
    parts.append((TESTS / test_file).read_text())
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as bundle:
        bundle.write("\n".join(parts))
    result = subprocess.run([LUAU, bundle.name], capture_output=True, text=True)
    print(result.stdout[-3000:], result.stderr[-3000:])
    return "0 échoués" in result.stdout

HUD = {
    "Items": SHARED + "Items.lua", "Rarities": SHARED + "Rarities.lua", "RollMath": SHARED + "RollMath.lua",
    "SkillTreeConfig": SHARED + "SkillTreeConfig.lua", "SkillTree": SHARED + "SkillTree.lua",
    "UIKit": SHARED + "UIKit.lua", "HudState": SHARED + "HudState.lua", "Grid": SHARED + "Grid.lua",
    "ItemVisuals": SHARED + "ItemVisuals.lua",
    "RollClient": "StarterPlayerScripts/RollClient.client.lua",
    "WaveClient": "StarterPlayerScripts/WaveClient.client.lua",
    "BuildClient": "StarterPlayerScripts/BuildClient.client.lua",
    "SwordClient": "StarterPlayerScripts/SwordClient.client.lua",
}

ok = run("prelude.luau", LOGIC, "skilltree_tests.luau")
ok = run("fakeroblox.luau", HUD, "hud_tests.luau", "Modules = {}") and ok
ok = run("fakeroblox.luau", UI, "ui_tests.luau", "Modules = {}") and ok
sys.exit(0 if ok else 1)
