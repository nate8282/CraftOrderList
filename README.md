# Craft Order List

Craft Order List is a World of Warcraft addon that gives you a visual shopping list for crafting materials. It shows what you need, what you have, and lets you search the Auction House directly from the list.

## Features
- Automatically builds a material shopping list from any recipe or crafting order.
- "Search AH" buttons on each material row to search the Auction House instantly.
- "Search Next" button cycles through all materials you still need more of, repeating until you've bought enough of each.
- Recent recipes dropdown for quick access to the last 5 recipes you loaded.
- Export button copies a shareable import string; restore it on any character with `/col import`.
- Completion notification when all materials are fully collected.
- Quantity multiplier (x1–x999) for batch crafting.
- Quality filter dropdown (Any, Rank 1, Rank 2, Rank 3).
- Sort by name, amount needed, completion status, or material source.
- Hide completed materials to focus on what you still need.
- Progress bar showing overall collection progress.
- Reagent source tooltips showing material type and subtype on hover.
- Quality tier quantity breakdown in material tooltips.
- Stack multiple recipes into one combined shopping list.
- Right-click materials to manually mark them as done.
- Draggable minimap button.
- Auto-docks next to the Auction House when opened.
- Keyboard shortcuts bindable via WoW's Key Bindings panel.
- Persists your shopping list and settings between sessions.

## How to Use
1. Install the addon by copying it into your WoW `Interface/AddOns` folder.
2. Open a profession window or crafting order form — you'll see a **Get Materials List** button.
3. Click it to build your shopping list. Click again on another recipe to add more materials.
4. Open the Auction House and the materials window will dock beside it.
5. Use the **Search AH** buttons or **Search Next** to find what you need.
6. When you're done shopping, click **Export** to save your list as a string you can share or restore later.

## Slash Commands
- `/col` — Toggle the materials window.
- `/col show` — Show the materials window.
- `/col hide` — Hide the materials window.
- `/col clear` — Clear the current shopping list.
- `/col reset` — Reset the window position to default.
- `/col import <string>` — Restore a material list from an export string.
- `/col help` — List all slash commands.

## Key Bindings
Two actions can be bound in the WoW **Key Bindings** panel under the **Craft Order List** header:
- **Toggle Materials List** — Show or hide the materials window.
- **Search Next Material** — Search the AH for the next material you still need.

## Installation
- Download from [CurseForge](https://www.curseforge.com/wow/addons/craftorderlist) or [GitHub Releases](https://github.com/nate8282/CraftOrderList/releases).
- Extract the folder to your World of Warcraft AddOns directory:
  `World of Warcraft/_retail_/Interface/AddOns/`
- Restart WoW or type `/reload` to load the addon.

## Contributing
If you would like to suggest changes or report bugs, feel free to open an issue or submit a pull request. Please ensure that your contributions maintain the project's standards.
