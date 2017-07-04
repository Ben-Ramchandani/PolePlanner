data:extend(
  {
    {
      type = "selection-tool",
      name = "pole-builder",
      icon = "__base__/graphics/icons/iron-stick.png",
      flags = {"goes-to-quickbar"},
      selection_color = {r = 1.0, g = 0.55, b = 0.0, a = 0.2},
      alt_selection_color = {r = 1.0, g = 0.2, b = 0.0, a = 0.2},
      selection_mode = {"deconstruct"},
      alt_selection_mode = {"deconstruct"},
      selection_cursor_box_type = "not-allowed",
      alt_selection_cursor_box_type = "not-allowed",
      subgroup = "tool",
      order = "c[automated-construction]-d[pole-builder]",
      stack_size = 1
    },
    {
        type = "recipe",
        name = "pole-builder",
        enabled = true,
        energy_required = 0.1,
        category = "crafting",
        ingredients = {},
        result = "pole-builder"
    },
  }
)

