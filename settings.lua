data:extend({
  {
    type = "bool-setting",
    name = "pipeline-hover-enabled",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "a",
  },
  {
    type = "bool-setting",
    name = "pipeline-hover-show-icons",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "b",
  },
  {
    type = "bool-setting",
    name = "pipeline-hover-show-contents",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "c",
  },
  {
    type = "int-setting",
    name = "pipeline-hover-max-nodes",
    setting_type = "runtime-per-user",
    default_value = 1500,
    minimum_value = 100,
    maximum_value = 10000,
    order = "d",
  },
})
