return {
    {
        UniqueId = "editor.$native.number",
        Name = "Default Number Editor",
        Description = "The number (non-integer) editor included with PropertiesMod",
        Attribution = "",

        Filters = {"Primitive:double", "Primitive:float"},
        EntryPoint = "number",
    },

    {
        UniqueId = "editor.$native.integer",
        Name = "Default Integer Editor",
        Description = "The integer editor included with PropertiesMod",
        Attribution = "",

        Filters = {"Primitive:int"},
        EntryPoint = "integer",
    }
}