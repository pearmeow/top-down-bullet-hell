# Room TileSet

Use `room_tileset.tres` with a Godot 4 `TileMapLayer`. Its grid is 16 × 16 pixels.

For a ready-made set of painting layers, open `res://scenes/room_template.tscn` and save a copy for each room. Paint floors on **Floors**, walls and larger room pieces on **Structures**, and props on **Decorations**. The TileSet palette has separate sources for floors, structures, decorations, and animated torches, candles, and spikes.

Large wall and doorway pieces are single stamps occupying multiple grid cells. The four `room_*.png` files are aligned atlases derived from the original images in this folder; keep them alongside `room_tileset.tres`.
