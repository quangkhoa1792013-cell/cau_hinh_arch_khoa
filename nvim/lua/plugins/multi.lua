return {
  "jake-stewart/multicursor.nvim",
  branch = "1.0",
  config = function()
    local mc = require("multicursor-nvim")
    mc.setup()

    local set = vim.keymap.set

    -- 1. Add cursors up/down (like Ctrl+Alt+Up/Down in VSCode)
    set({ "n", "x" }, "<S-M-Down>", function() mc.lineAddCursor(1) end, { desc = "MC: Add cursor down" })
    set({ "n", "x" }, "<S-M-Up>", function() mc.lineAddCursor(-1) end, { desc = "MC: Add cursor up" })

    -- 2. Ctrl+D: Select next match (like VSCode)
    set({ "n", "x" }, "<C-d>", function() mc.matchAddCursor(1) end, { desc = "MC: Select next match" })

    -- 3. Ctrl+Shift+L: Select all matches (like VSCode)
    set({ "n", "x" }, "<C-S-l>", mc.matchAllAddCursors, { desc = "MC: Select all matches" })

    -- 4. Ctrl+U: Undo last cursor (like VSCode)
    set({ "n", "x" }, "<C-u>", mc.restoreCursors, { desc = "MC: Undo last cursor" })

    -- 5. Skip cursor (for Ctrl+K Ctrl+D pattern)
    set({ "n", "x" }, "<C-S-d>", function() mc.matchSkipCursor(1) end, { desc = "MC: Skip match" })

    -- 6. Alt+Click: Add cursor with mouse (like VSCode)
    set("n", "<A-leftmouse>", mc.handleMouse)
    set("n", "<A-leftdrag>", mc.handleMouseDrag)
    set("n", "<A-leftrelease>", mc.handleMouseRelease)

    -- 7. Shift+Alt+Drag: Box selection (like VSCode)
    set("v", "<S-M-Down>", function() mc.lineAddCursor(1) end, { desc = "MC: Add cursor down" })
    set("v", "<S-M-Up>", function() mc.lineAddCursor(-1) end, { desc = "MC: Add cursor up" })

    -- 8. Toggle cursor on/off
    set({ "n", "x" }, "<C-q>", mc.toggleCursor, { desc = "MC: Toggle cursor" })

    -- Keymap layer: only active when multi-cursor is ON
    mc.addKeymapLayer(function(layerSet)
      -- Navigate between cursors
      layerSet({ "n", "x" }, "<left>", mc.prevCursor)
      layerSet({ "n", "x" }, "<right>", mc.nextCursor)

      -- Delete current cursor
      layerSet({ "n", "x" }, "<S-M-Delete>", mc.deleteCursor)

      -- Esc: clear all cursors (like VSCode)
      layerSet("n", "<esc>", function()
        if not mc.cursorsEnabled() then
          mc.enableCursors()
        else
          mc.clearCursors()
        end
      end)
    end)

    -- Highlights
    local hl = vim.api.nvim_set_hl
    hl(0, "MultiCursorCursor", { reverse = true })
    hl(0, "MultiCursorVisual", { link = "Visual" })
    hl(0, "MultiCursorSign", { link = "SignColumn" })
    hl(0, "MultiCursorMatchPreview", { link = "Search" })
    hl(0, "MultiCursorDisabledCursor", { reverse = true })
    hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
    hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
  end,
}
