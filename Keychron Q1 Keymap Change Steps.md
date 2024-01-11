# Keychron Q1 Keymap Change Steps

Two keyboards:
1. Keychron Q1 v2 (2022-03-18)
2. Keychron Q1 Pro (2023-07-13)

Notes
- making changes in the **Configure** tab of VIA writes to the keyboard's firmware immediately. There's no "test my changes first" concept.
- To use the Layer 1 keymap, the modifier key is Right Alt/Option, shown in VIA as *MO(1)*.

## 1. Load VIA App

Note: VIA typically won't auto-recognize keyboard.

## 2. Go to **DESIGN** tab

 Note: may have to enable first under the **Settings** tab.
 
1. Enable the toggle "Use V2 definitions (deprecated)"
2. Load the Draft Definition `KeychronQ1_V2_US_ANSI_Knob_V2.5.json`
3. It may give errors, but check if the **Configure** tab loads now.


## 3. Make changes in the **CONFIGURE** tab.

1. *No need to load another JSON file*. It's showing what is currently mapped in the keyboard's firmware.
2. However, can make a *backup* prior to making changes by doing a **Save** to `KeychronQ1_V2_Keymap.json`.
3. When finished, make a by doing a **Save** to `KeychronQ1_V2_Keymap.json`.


