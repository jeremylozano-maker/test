-- HudState : mode d'affichage de l'interface, partagé par tous les LocalScripts du joueur
--   "Main"  = écran normal (Build | ROLL | Skills en bas)
--   "Roll"  = fenêtre des dés ouverte (Auto Roll | ROLL | Fermer en bas)
--   "Build" = mode construction (fenêtre des objets à gauche, Exit | Delete en bas)
-- Un ModuleScript n'est chargé qu'une fois par joueur : tous les scripts voient le même mode.
local HudState = {}

HudState.Mode = "Main"

local changedEvent = Instance.new("BindableEvent")
HudState.Changed = changedEvent.Event -- (nouveau mode)

function HudState.SetMode(mode)
	if HudState.Mode ~= mode then
		HudState.Mode = mode
		changedEvent:Fire(mode)
	end
end

return HudState
