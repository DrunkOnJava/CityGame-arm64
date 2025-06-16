# SimCity ARM64 - Complete City Building Demo

## Utility-Gated Growth System Test

### Step 1: Place Utilities
1. Press `4` - Select Coal Power Plant tool
2. Click center of map to place power plant (⚡ icon appears)
3. Press `5` - Select Water Pump tool  
4. Click near power plant to place water pump (💧 icon appears)

### Step 2: Check Coverage
1. Press `E` - View power overlay (yellow gradient shows coverage)
2. Press `W` - View water overlay (blue gradient shows coverage)
3. Press `N` - Return to normal view

### Step 3: Zone Development Areas
1. Press `1` - Select Residential zoning (green)
2. Click and drag within utility coverage area
3. Press `2` - Select Commercial zoning (blue)
4. Zone some commercial near residential
5. Press `3` - Select Industrial zoning (yellow)
6. Zone industrial areas with good utility coverage

### Step 4: Observe Growth
- Wait 5-10 seconds (150-300 frames)
- Buildings will ONLY grow where both power AND water exist
- Zones without utilities show Zot indicators (⚡💧)
- Watch stats update:
  - Power demand increases as buildings develop
  - Population grows in residential zones
  - Jobs appear in commercial/industrial zones

### Expected Results
✅ Utility buildings visible on map
✅ Power/Water overlays show coverage gradients
✅ Buildings develop only in serviced areas
✅ Zot warnings on unserviced zones
✅ Stats reflect actual utility usage and population

### Key Insight
This perfectly mirrors SimCity 4's dependency system where zones cannot develop without basic services. The flood-fill propagation ensures realistic utility networks!