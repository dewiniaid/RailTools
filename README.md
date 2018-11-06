# RailTools

Factorio only shows up to 5 train ghosts, which can complicate building railways with 6 or more wagons (including the
common size 6 trains of LL-CCCC or L-CCCC-L).

Railtools aims to alleviate this pain by calculating distances between signals, highlighting possible problem areas, 
and adding tools to create safe-sized areas at the end of a railway junction (by means of placing properly positioned
rail signal ghosts)

**This mod is not a replacement for proper signalling techniques, it just makes executing said techniques easier.**

## TL;DR Quick Instructions
1. Change keybindings if desired.
2. Configure your train length and desired signal separation in Mod Settings -> Per Player.  *Note that these sizes
  are in tiles.  A vanilla train is `(7 * num_wagons)-1` tiles wide.*
3. Configure the maximum search distance and maximum signals placed at once in Mod Settings -> Map.  Larger values
   may affect performance.  Maximum search distance *must* be at least as large as your largest train, ideally somewhat
   bigger.
4. To create a 'safe space' one train-length wide after a junction, select the rail signal at the end of the junction
and press `BACKSLASH`.   
5. To automatically place signals between a rail signal and the next junction (or existing signal), highlight the signal
and press `SHIFT + BACKSLASH`.  (This also works on bidirectional rail with chain signals, if you do that sort of thing)
6. If you see red highlights, you may have something wrong with your track design. 

## Distance Display

When hovering over a signal, the distance to nearby signals is displayed.  Usually this is all signals one step 'in front'
of the selected signal and all signals one step 'behind' the selected signal.  In some cases this will extend to signals 
outside of the current block (like in the rightmost rail signal in the screenshot).  The first number shown is the
distance in tiles, the second the distance in standard vanilla wagon lengths.

In some cases, the distance shown will be for a different chunk of rail than the current one.  For instance, chain
signals look for the next rail signal and will also show the distance between that rail signal and the following
signal -- if this is smaller than your maximum train size, you may have problems!

If you have an area after a junction exit that is not big enough to hold a train, signals related to it will be 
highlighted in red.  This [example Image](https://i.imgur.com/Nt3USNn.png) shows an errant rail signal that's placed
too close for 6-wagon-long trains.  You can configure your train length in `Mod Settings -> Per Player`

### Sidebar: A note on distance calculations

Distances in this mod are better thought of "the largest train that can fit between these two signals".  Because of 
quirks in where trains can actually stop, adding two distances together does not necessarily give a correct result
for the total distance between those two sections of rail.  

For example, deleting the left highlighted rail signal in the example image results in a section that is 17 tiles wide,
rather than 16 -- despite the fact the two sections involved are 3 and 13 tiles wide respectively.

## Create Exit Blocks
Pressing `BACKSLASH` while hovering over a rail (not chain) signal will place a new rail signal far enough away that
a train can fit within the space.  Use this on the first rail signal at the end of a junction.  You can configure your
 rain length in `Mod Settings -> Per Player`

If the track past this signal happens to branch, signals will be placed on each branch of the track as needed.  If any
signals already exist, signal placement along that branch will be skipped.

While this ensures a train coming from your selected signal will fit in the newly-signalled space, it **does not** look 
at any other signals that might lead in to the same block.  You can always hover over the newly-placed signal and ensure 
it's the correct distance from any other signals that might exist, though.

## Place Automatic Signals
Pressing `SHIFT+BACKSLASH` on a rail signal will follow a rail line until it reaches an existing signal, junction or
dead end and places signals periodically.  This spacing can be configured in `Mod Settings -> Per Player`.  It is not
the same as your train length.

If you are using bidirectional track, pressing `SHIFT+BACKSLASH` on a chain signals will place pairs of chain signals
along the track.  

## Placement rules
All signal placement is done through ghosts, so it requires construction robots to be most useful.  This may change
in a later release.

If a signal can't be placed due to trees or rocks, they are marked for deconstruction just like shift-clicking a
blueprint of a signal would do.  In the case of other obstructions, RailTools will try again in the next place a signal
could potentially be until it finds a suitable location, exceeds its maximum search distance, or encounters an
existing signal.

When creating an exit block, splits in the track will be followed; any other junctions will be ignored.  When 
autosignalling, any sort of branch will end signal placement.


### 0.1.0 (2018-11-05)

* Possibly fixes a crash related to `revive_hack`.

### 0.2.0 (2018-10-23)

* Add support for accumulators, solar panels, and furnaces.
* Properly detect and handle entities with burners instead of inadvertently clobbering their fuel state.
* Skip entities that have a non-empty module inventory or a non-empty output inventory in addition to other checks.

### 0.1.0 (2018-10-20)
 
* First release
