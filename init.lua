-- C#-oriented Neovim configuration. Feature modules keep this entrypoint small.
require("neo.options").setup()
require("neo.keymaps").setup()
require("neo.session").setup()
require("neo.terminal").setup()
require("neo.csharp").setup()
require("neo.ui").setup()
require("neo.plugins").setup()
