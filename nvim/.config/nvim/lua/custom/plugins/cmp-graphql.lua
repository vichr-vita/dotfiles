return {
  "phenax/cmp-graphql",
  config = function()
    require("cmp-graphql").setup {
      schema_path = "graphql.schema.json"
    }
  end
}
