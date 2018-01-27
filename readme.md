Eco Visualizer
==============


known limitations
-----------------

* bubble culling using midpoint
* initial setup slow (depending on map)
* only update tree when showing (pro: no slowdown at all when not used, con: might take a moment to update after many changes)

* not *everything* reclaimable is shown, the game simply doesn't provide this info to UI
* no updates for partially reclaimed stuff: still same amount shown -> game doesn't provide this info either


Eco Predict
===========


TODO
----

Prediction:
* Stall slowdown
	* How does energy stall affect mass generation?
	* Energy usage of shields etc.?
* Adjancency Bonus
* Reclaim
* Time til project finished
	* paused upgrades (e.g. mexes)
	* supporting build power
* build queues
	* repeat
	* walk times between buildings, factory run-off delay
* regen, repair
* upgrades



Heatmap:
* implement hotkey instead of showing it all the time ;)
* also show resource consumption and generation
* maybe also estimates from enemies
* find good way of updating heatmap without slowing down GUI too much
* resize heatmap when window/viewport is resized
* add options (keymapping, resolution, colorscheme/mapping)

Cluster Heatmap:
* optimize clustering (maybe create a few discrete LOD levels)
* find proper formula for cluster threshold (based on zoom, weighted position and mass)
* implement for resource consumption too

Permanent Limitations:
* Reclaim info is very limited. Smaller trees and rocks etc. are not accessible from UI side.