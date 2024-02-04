# Spoons
Personal repository of Hammerspoon plugins.

# How to Use

## Automated

Installation of Spoons from this repository can be automated with [SpoonInstall](https://www.hammerspoon.org/Spoons/SpoonInstall.html). Once you have manually installed `SpoonInstall`, it can be configured to use this repository:

```load
hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos.adammillerio = {
    url = "https://github.com/adammillerio/Spoons",
    desc = "adammillerio Personal Spoon repository",
    branch = "main"
}

spoon.SpoonInstall:andUse("Spacer", {repo = "adammillerio", start = true})
```

## Manual

Download any Spoon zip from the `Spoons` directory, unzip it, and either double click to install or move it to `~/.hammerspoon/Spoons`. Then you can load it in your `init.lua`:

```lua
hs.loadSpoon("Spacer")
```
